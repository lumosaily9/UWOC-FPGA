#ifndef UWOC_TEST_TYPES_H
#define UWOC_TEST_TYPES_H
typedef unsigned char u8;
typedef unsigned short u16_t;
typedef unsigned int u32;
typedef unsigned long long u64_t;
typedef unsigned long long UINTPTR;
#define NULL ((void *)0)
#define XST_SUCCESS 0
#define XST_FAILURE 1
typedef int err_t;
#define ERR_OK 0
typedef struct { unsigned int addr; } ip_addr_t;
typedef struct { unsigned int addr; } ip4_addr_t;
struct netif { ip_addr_t ip_addr, netmask, gw; };
#define ip4_addr1(x) 192
#define ip4_addr2(x) 168
#define ip4_addr3(x) 253
#define ip4_addr4(x) 103
#endif
