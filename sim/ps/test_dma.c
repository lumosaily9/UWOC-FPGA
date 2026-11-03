#include "xaxidma.h"
#include "xscugic.h"
static XAxiDma_Config cfg;
static int no_config, init_status, sg_mode, transfer_status;
static int reset_done=1, reset_calls, enable_calls, disable_calls;
static int sequence, flush_order, transfer_order, invalidate_calls;
static u32 irq_status, recorded_length;
int xil_printf(const char *s, ...) { (void)s; return 0; }
XAxiDma_Config *XAxiDma_LookupConfig(int id)
{ (void)id; return no_config ? NULL : &cfg; }
int XAxiDma_CfgInitialize(XAxiDma *a, XAxiDma_Config *b)
{ (void)a; (void)b; return init_status; }
int XAxiDma_HasSg(XAxiDma *a) { (void)a; return sg_mode; }
int XAxiDma_SimpleTransfer(XAxiDma *a, UINTPTR p,u32 n,int d)
{ (void)a; (void)p; (void)d; recorded_length=n; transfer_order=++sequence; return transfer_status; }
void XAxiDma_Reset(XAxiDma *a) { (void)a; ++reset_calls; }
int XAxiDma_ResetIsDone(XAxiDma *a) { (void)a; return reset_done; }
void XAxiDma_IntrDisable(XAxiDma *a,u32 m,int d)
{ (void)a; (void)m; (void)d; ++disable_calls; }
void XAxiDma_IntrEnable(XAxiDma *a,u32 m,int d)
{ (void)a; (void)m; (void)d; ++enable_calls; }
u32 XAxiDma_IntrGetIrq(XAxiDma *a,int d) { (void)a; (void)d; return irq_status; }
void XAxiDma_IntrAckIrq(XAxiDma *a,u32 m,int d) { (void)a; (void)m; (void)d; }
void Xil_DCacheFlushRange(UINTPTR p,u32 n)
{ (void)p; (void)n; flush_order=++sequence; }
void Xil_DCacheInvalidateRange(UINTPTR p,u32 n)
{ (void)p; (void)n; ++invalidate_calls; }
void XScuGic_SetPriorityTriggerType(XScuGic*a,int b,unsigned int c,unsigned int d)
{ (void)a; (void)b; (void)c; (void)d; }
int XScuGic_Connect(XScuGic*a,int b,Xil_InterruptHandler c,void*d)
{ (void)a; (void)b; (void)c; (void)d; return 0; }
void XScuGic_Enable(XScuGic*a,int b) { (void)a; (void)b; }
#include "../../src/ps/rx/axi_dma/axi_dma.c"
#define CHECK(x,n) do { if (!(x)) return n; } while (0)
int main(void)
{
    no_config=1; CHECK(axi_dma_cfg()==XST_FAILURE,21);
    no_config=0; init_status=1; CHECK(axi_dma_cfg()==XST_FAILURE,22);
    init_status=0; sg_mode=1; CHECK(axi_dma_cfg()==XST_FAILURE,23);
    sg_mode=0; CHECK(axi_dma_cfg()==XST_SUCCESS,24);
    CHECK(axi_dma_start(0)==XST_FAILURE && axi_dma_start(301)==XST_FAILURE,25);
    transfer_status=1; CHECK(axi_dma_start(300)==XST_FAILURE,26);
    transfer_status=0; CHECK(axi_dma_start(300)==XST_SUCCESS,27);
    CHECK(recorded_length==300 && flush_order<transfer_order,28);
    irq_status=XAXIDMA_IRQ_IOC_MASK; rx_intr_handler(&axidma);
    CHECK(rx_done==1 && invalidate_calls==1,29);
    irq_status=XAXIDMA_IRQ_ERROR_MASK|XAXIDMA_IRQ_IOC_MASK;
    rx_intr_handler(&axidma);
    CHECK(error==1 && rx_done==0 && invalidate_calls==1 && disable_calls==1,30);
    CHECK(axi_dma_recover()==XST_SUCCESS && error==0 && rx_done==0 && enable_calls==1,31);
    reset_done=0; CHECK(axi_dma_recover()==XST_FAILURE,32);
    CHECK(reset_calls==2,33);
    return 0;
}
