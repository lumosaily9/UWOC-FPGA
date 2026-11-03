#ifndef UWOC_TEST_DMA_H
#define UWOC_TEST_DMA_H
#include "test_types.h"
typedef struct { int x; } XAxiDma;
typedef struct { int x; } XAxiDma_Config;
#define XAXIDMA_DEVICE_TO_DMA 1
#define XAXIDMA_IRQ_ERROR_MASK 4U
#define XAXIDMA_IRQ_IOC_MASK 1U
#define XAXIDMA_IRQ_ALL_MASK 7U
XAxiDma_Config *XAxiDma_LookupConfig(int);
int XAxiDma_CfgInitialize(XAxiDma *, XAxiDma_Config *);
int XAxiDma_HasSg(XAxiDma *);
int XAxiDma_SimpleTransfer(XAxiDma *, UINTPTR, u32, int);
void XAxiDma_Reset(XAxiDma *);
int XAxiDma_ResetIsDone(XAxiDma *);
void XAxiDma_IntrDisable(XAxiDma *, u32, int);
void XAxiDma_IntrEnable(XAxiDma *, u32, int);
u32 XAxiDma_IntrGetIrq(XAxiDma *, int);
void XAxiDma_IntrAckIrq(XAxiDma *, u32, int);
#endif
