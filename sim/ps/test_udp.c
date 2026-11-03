#include "lwip/udp.h"
static struct udp_pcb test_pcb;
static struct pbuf test_pbuf;
static int bind_result, connect_result, alloc_calls, sent, freed, removed;
static unsigned int allocated_length, copied_length;
static int fail_alloc;
int xil_printf(const char *s, ...) { (void)s; return 0; }
struct udp_pcb *udp_new(void) { return &test_pcb; }
err_t udp_bind(struct udp_pcb *p, const ip_addr_t *a, u16_t b)
{ (void)p; (void)a; (void)b; return bind_result; }
err_t udp_connect(struct udp_pcb *p, const ip_addr_t *a, u16_t b)
{ (void)p; (void)a; (void)b; return connect_result; }
void udp_remove(struct udp_pcb *p) { (void)p; ++removed; }
struct pbuf *pbuf_alloc(int a, u16_t n, int b)
{ (void)a; (void)b; ++alloc_calls; allocated_length=n; return fail_alloc ? NULL : &test_pbuf; }
err_t pbuf_take(struct pbuf *p, const void *d, u16_t n)
{ (void)p; (void)d; copied_length=n; return ERR_OK; }
err_t udp_send(struct udp_pcb *p, struct pbuf *b)
{ (void)p; (void)b; ++sent; return ERR_OK; }
void pbuf_free(struct pbuf *p) { (void)p; ++freed; }
#include "../../src/ps/rx/udp_perf_server.c"
#define CHECK(x,n) do { if (!(x)) return n; } while (0)
int main(void)
{
    u8 data=0;
    unsigned int lens[5]={1,7,239,300,65507};
    int i, before;
    udp_tx_data(&data,239); CHECK(alloc_calls==0,11);
    start_application();
    for (i=0;i<5;++i) {
        udp_tx_data(&data,lens[i]);
        CHECK(allocated_length==lens[i] && copied_length==lens[i],12);
    }
    CHECK(sent==5 && freed==5,13);
    before=alloc_calls;
    udp_tx_data(&data,0); udp_tx_data(NULL,239); udp_tx_data(&data,65508);
    CHECK(alloc_calls==before,14);
    fail_alloc=1; udp_tx_data(&data,239); CHECK(sent==5,15); fail_alloc=0;
    bind_result=1; start_application(); before=alloc_calls;
    udp_tx_data(&data,239); CHECK(alloc_calls==before && removed==1,16);
    bind_result=0; connect_result=1; start_application();
    before=alloc_calls; udp_tx_data(&data,239);
    CHECK(alloc_calls==before && removed==2,17);
    return 0;
}
