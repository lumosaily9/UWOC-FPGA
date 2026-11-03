#ifndef UWOC_TEST_GIC_H
#define UWOC_TEST_GIC_H
#include "test_types.h"
typedef struct { int x; } XScuGic;
typedef void (*Xil_InterruptHandler)(void *);
void XScuGic_SetPriorityTriggerType(XScuGic *, int, unsigned int, unsigned int);
int XScuGic_Connect(XScuGic *, int, Xil_InterruptHandler, void *);
void XScuGic_Enable(XScuGic *, int);
#endif
