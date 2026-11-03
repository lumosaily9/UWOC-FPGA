#ifndef UWOC_TEST_UDP_H
#define UWOC_TEST_UDP_H
#include "test_types.h"
struct udp_pcb { int x; };
struct pbuf { int x; };
#define PBUF_TRANSPORT 0
#define PBUF_POOL 0
#define IP_ADDR_ANY ((ip_addr_t *)0)
struct udp_pcb *udp_new(void);
err_t udp_bind(struct udp_pcb *, const ip_addr_t *, u16_t);
err_t udp_connect(struct udp_pcb *, const ip_addr_t *, u16_t);
void udp_remove(struct udp_pcb *);
struct pbuf *pbuf_alloc(int, u16_t, int);
err_t pbuf_take(struct pbuf *, const void *, u16_t);
err_t udp_send(struct udp_pcb *, struct pbuf *);
void pbuf_free(struct pbuf *);
#endif
