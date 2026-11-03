#include "test_types.h"
#include "xscugic.h"
volatile int rx_done, error;
static u8 dummy_buffer[300];
u8 *rx_buffer_ptr=dummy_buffer;
static int loop_count, start_calls, recover_calls, udp_calls, bad_length;
int xil_printf(const char*s, ...) { (void)s; return 0; }
void print(const char*s) { (void)s; }
void axi_gpio_init(void) {}
int axi_dma_cfg(void) { return 0; }
int Init_Intr_System(XScuGic*p) { (void)p; return 0; }
void Setup_Intr_Exception(XScuGic*p) { (void)p; }
int dma_setup_intr_system(XScuGic*p) { (void)p; return 0; }
void xemacif_input(struct netif*p)
{
    (void)p; ++loop_count;
    if (loop_count==3 || loop_count==5) error=1;
    if (loop_count==4) rx_done=1;
}
u32 get_fifo_count(void) { return loop_count==4 ? 0U : 300U; }
int axi_dma_start(u32 n)
{ ++start_calls; bad_length|=(n!=300U); return start_calls==1 ? 1 : 0; }
int axi_dma_recover(void)
{ ++recover_calls; error=0; rx_done=0; return loop_count==5 ? 1 : 0; }
void udp_tx_data(u8*p,unsigned int n)
{ (void)p; ++udp_calls; bad_length|=(n!=239U); }
void start_application(void) {}
void print_app_header(void) {}
void lwip_init(void) {}
int xemac_add(struct netif*a,void*b,void*c,void*d,unsigned char*e,unsigned int f)
{ (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; return 1; }
void netif_set_default(struct netif*p) { (void)p; }
void netif_set_up(struct netif*p) { (void)p; }
int inet_aton(const char*s,ip_addr_t*p) { (void)s; p->addr=0; return 1; }
#define main firmware_main
#include "../../src/ps/rx/main.c"
#undef main
int main(void)
{
    int result=firmware_main();
    if (result!=XST_FAILURE) return 41;
    if (loop_count!=5 || start_calls!=3 || recover_calls!=3) return 42;
    if (udp_calls!=1 || bad_length || dma_start_flag!=0 || rx_done!=0) return 43;
    return 0;
}
