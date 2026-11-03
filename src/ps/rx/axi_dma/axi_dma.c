//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           axi_dma.c
// Last modified Date:  2023/08/9 10:59:46
// Last Version:        V1.0
// Descriptions:        Axi dma驱动程序在中断模式下接收数据包
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2019/06/30 15:59:52
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

/***************************** Include Files *********************************/
#include "axi_dma.h"
#include "xil_cache.h"
#include "xil_printf.h"

#define DMA_DEV_ID XPAR_AXIDMA_0_DEVICE_ID
#define RX_INTR_ID XPAR_FABRIC_AXIDMA_0_VEC_ID
#define DDR_BASE_ADDR XPAR_PS7_DDR_0_S_AXI_BASEADDR
#define MEM_BASE_ADDR (DDR_BASE_ADDR + 0x1000000U)
#define RX_BUFFER_BASE (MEM_BASE_ADDR + 0x00300000U)
#define RESET_TIMEOUT_COUNTER 10000U

static XAxiDma axidma;
static u32 rx_buffer_capacity;
volatile int rx_done = 0;
volatile int error = 0;
u8 *rx_buffer_ptr;

int axi_dma_cfg(void)
{
    XAxiDma_Config *config;
    int status;
    rx_buffer_ptr = (u8 *)RX_BUFFER_BASE;
    rx_done = 0;
    error = 0;
    rx_buffer_capacity = 0U;
    config = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (config == NULL) {
        xil_printf("DMA configuration not found\r\n");
        return XST_FAILURE;
    }
    status = XAxiDma_CfgInitialize(&axidma, config);
    if (status != XST_SUCCESS || XAxiDma_HasSg(&axidma)) {
        xil_printf("DMA simple-mode initialization failed\r\n");
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

int axi_dma_start(u32 pkt_len)
{
    int status;
    if (pkt_len == 0U || pkt_len > AXI_DMA_RX_BUFFER_CAPACITY) {
        return XST_FAILURE;
    }
    rx_done = 0;
    error = 0;
    rx_buffer_capacity = pkt_len;
    /* Release any dirty cache lines before the device starts writing DDR. */
    Xil_DCacheFlushRange((UINTPTR)rx_buffer_ptr, pkt_len);
    status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)rx_buffer_ptr,
                                   pkt_len, XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) {
        xil_printf("DMA start failed: %d\r\n", status);
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

/* Recovery runs in the application loop instead of waiting in the ISR. */
int axi_dma_recover(void)
{
    u32 timeout = RESET_TIMEOUT_COUNTER;
    XAxiDma_IntrDisable(&axidma, XAXIDMA_IRQ_ALL_MASK,
                        XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_Reset(&axidma);
    while (timeout != 0U && !XAxiDma_ResetIsDone(&axidma)) {
        --timeout;
    }
    if (timeout == 0U) {
        xil_printf("DMA reset timeout\r\n");
        return XST_FAILURE;
    }
    XAxiDma_IntrAckIrq(&axidma, XAXIDMA_IRQ_ALL_MASK,
                       XAXIDMA_DEVICE_TO_DMA);
    rx_done = 0;
    error = 0;
    XAxiDma_IntrEnable(&axidma, XAXIDMA_IRQ_ALL_MASK,
                       XAXIDMA_DEVICE_TO_DMA);
    return XST_SUCCESS;
}

void rx_intr_handler(void *callback)
{
    XAxiDma *instance = (XAxiDma *)callback;
    u32 irq_status = XAxiDma_IntrGetIrq(instance, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrAckIrq(instance, irq_status, XAXIDMA_DEVICE_TO_DMA);
    if ((irq_status & XAXIDMA_IRQ_ERROR_MASK) != 0U) {
        XAxiDma_IntrDisable(instance, XAXIDMA_IRQ_ALL_MASK,
                            XAXIDMA_DEVICE_TO_DMA);
        rx_done = 0;
        error = 1;
        return;
    }
    if ((irq_status & XAXIDMA_IRQ_IOC_MASK) != 0U) {
        /* TLAST ends the 239-byte information frame inside the 300-byte buffer. */
        Xil_DCacheInvalidateRange((UINTPTR)rx_buffer_ptr, rx_buffer_capacity);
        rx_done = 1;
    }
}

int dma_setup_intr_system(XScuGic *controller)
{
    int status;
    XScuGic_SetPriorityTriggerType(controller, RX_INTR_ID, 0xA0U, 0x3U);
    status = XScuGic_Connect(controller, RX_INTR_ID,
                            (Xil_InterruptHandler)rx_intr_handler, &axidma);
    if (status != XST_SUCCESS) {
        return status;
    }
    XScuGic_Enable(controller, RX_INTR_ID);
    XAxiDma_IntrEnable(&axidma, XAXIDMA_IRQ_ALL_MASK,
                       XAXIDMA_DEVICE_TO_DMA);
    return XST_SUCCESS;
}
