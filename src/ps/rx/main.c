 #include <stdio.h>
 #include <stdlib.h>
 #include <string.h>

 #include "xil_types.h"
 #include "xparameters.h"

 #include "axi_gpio_cfg/axi_gpio_cfg.h"
 #include "axi_dma/axi_dma.h"

 #include "sys_intr/sys_intr.h"

 #include "udp_perf_server.h"
 #include "netif/xadapter.h"
 #include "platform.h"
 #include "platform_config.h"
 #include "xil_printf.h"
 #include "lwip/tcp.h"

 #include "sleep.h"
 #include "lwip/priv/tcp_priv.h"
 #include "lwip/init.h"
 #include "lwip/inet.h"
 #include "xil_cache.h"

 extern volatile int TcpFastTmrFlag;
 extern volatile int TcpSlowTmrFlag;

 #define DEFAULT_IP_ADDRESS  "192.168.253.103"
 #define DEFAULT_IP_MASK     "255.255.255.0"
 #define DEFAULT_GW_ADDRESS  "192.168.253.254"

 void start_application(void);
 void print_app_header(void);
 int lwip_udp_init();
 #define MAX_PKT_LEN     300U    // FIFO threshold and receive buffer capacity

 //函数声明
 struct netif *netif;
 extern volatile int rx_done;
 extern u8 *rx_buffer_ptr;
 u32 fifo_count = 0;
 u8 dma_start_flag = 0;            // 0: idle, 1: DMA receive active

 struct netif server_netif;
 static XScuGic Intc;              //GIC


 int main(void)
 {
	 xil_printf("\r\n\r\n");
	      xil_printf("-----lwIP RAW Mode UDP Server Application-----\r\n");


     axi_gpio_init();
     if (axi_dma_cfg() != XST_SUCCESS) return XST_FAILURE;
     if (Init_Intr_System(&Intc) != XST_SUCCESS) return XST_FAILURE;
     Setup_Intr_Exception(&Intc);
     if (dma_setup_intr_system(&Intc) != XST_SUCCESS) return XST_FAILURE;
     if (lwip_udp_init() != 0) return XST_FAILURE;

     while (1) {
         xemacif_input(netif);
         if (error) {
             xil_printf("DMA receive error, resetting channel\r\n");
             dma_start_flag = 0;
             rx_done = 0;
             if (axi_dma_recover() != XST_SUCCESS) return XST_FAILURE;
         }

         if (rx_done) {
             udp_tx_data(rx_buffer_ptr, 239U);
             rx_done = 0;
             dma_start_flag = 0;
         }

         fifo_count = get_fifo_count();
         if (fifo_count >= MAX_PKT_LEN && dma_start_flag == 0U) {
             if (axi_dma_start(MAX_PKT_LEN) == XST_SUCCESS) {
                 dma_start_flag = 1U;
             } else {
                 dma_start_flag = 0U;
                 if (axi_dma_recover() != XST_SUCCESS) return XST_FAILURE;
             }
         }
     }
     return 0;
 }

 static void print_ip(char *msg, ip_addr_t *ip)
 {
     print(msg);
     xil_printf("%d.%d.%d.%d\r\n", ip4_addr1(ip), ip4_addr2(ip),
             ip4_addr3(ip), ip4_addr4(ip));
 }

 static void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
 {
     print_ip("Board IP:       ", ip);
     print_ip("Netmask :       ", mask);
     print_ip("Gateway :       ", gw);
 }

 //设置静态IP地址
 static void assign_default_ip(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
 {
     int err;

     xil_printf("Configuring default IP %s \r\n", DEFAULT_IP_ADDRESS);

     err = inet_aton(DEFAULT_IP_ADDRESS, ip);
     if (!err)
         xil_printf("Invalid default IP address: %d\r\n", err);

     err = inet_aton(DEFAULT_IP_MASK, mask);
     if (!err)
         xil_printf("Invalid default IP MASK: %d\r\n", err);

     err = inet_aton(DEFAULT_GW_ADDRESS, gw);
     if (!err)
         xil_printf("Invalid default gateway address: %d\r\n", err);
 }

 int lwip_udp_init()
 {
     /*配置以太网MAC地址 */
     unsigned char mac_ethernet_address[] = {
         0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 };

     netif = &server_netif;

     xil_printf("\r\n\r\n");
     xil_printf("-----lwIP RAW Mode UDP Server Application-----\r\n");

     /* 初始化lwIP*/
     lwip_init();

     /* 将网络接口添加到netif_list，并将其设置为默认网络接口 （用于输出未找到特定路由的所有数据包） */
     if (!xemac_add(netif, NULL, NULL, NULL, mac_ethernet_address,
                 PLATFORM_EMAC_BASEADDR)) {
         xil_printf("Error adding N/W interface\r\n");
         return -1;
     }
     netif_set_default(netif);

     /* 指定网络是否已启动*/
     netif_set_up(netif);

     //设置静态IP地址
     assign_default_ip(&(netif->ip_addr), &(netif->netmask), &(netif->gw));

     //打印IP设置
     print_ip_settings(&(netif->ip_addr), &(netif->netmask), &(netif->gw));

     xil_printf("\r\n");

     /* 打印应用程序标题 */
     print_app_header();

     /* 启动应用程序*/
     start_application();
     xil_printf("\r\n");
     return 0;
 }


