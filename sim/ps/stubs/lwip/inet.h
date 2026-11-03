#include "test_types.h"
#define IP4_ADDR(ptr,a,b,c,d) ((ptr)->addr = 0U)
int inet_aton(const char *, ip_addr_t *);
