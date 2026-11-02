# 接收端 PS 应用

源码来自原工作区 `Enbedded_Vitis/camera_rs_rx_`，收录到仓库的 `7010_CAMERA_RS_RX/7010_camera_rs_rx/vitis/` 下。

## 用途与确认依据

这是运行在 Zynq PS Cortex-A9 上的 standalone 接收应用。原 `camera_rs_rx.prj` 指定了 `ps7_cortexa9_0`、standalone 和 `lwip_udp_perf_server` 模板；实际源码已经改为将 PL 接收的数据通过 UDP 转发给电脑。

1. `axi_gpio_cfg/` 使用 `XGpio_DiscreteRead` 获取 PL 侧 FIFO 计数。
2. `main.c` 在 FIFO 计数达到 `MAX_PKT_LEN = 300` 时启动 AXI DMA。
3. `axi_dma/` 使用 simple DMA 的 S2MM 通道，将数据写入 DDR；DMA 完成中断设置 `rx_done`。
4. 主循环看到 `rx_done` 后，调用 `udp_tx_data(rx_buffer_ptr, 239)`，将缓冲区中的 239 字节通过 lwIP RAW UDP 发出。

这些行为表明它是接收端的数据搬运与网络转发程序。程序名中的 `rs` 不表示 PS 软件执行了 RS 解码；原硬件导出中的 RS 解码由 PL 的 `rs_decoder_0` 完成。

## 目录与文件

| 路径（相对于 `vitis/`） | 用途 |
| --- | --- |
| `camera_rs_rx/src/main.c` | 应用入口、网络配置、FIFO 计数轮询和 DMA/UDP 调度。 |
| `camera_rs_rx/src/udp_perf_server.c`、`.h` | 创建 UDP PCB、绑定/连接端口、分配 pbuf 并发送数据。当前发送长度在实现中固定为 239 字节。 |
| `camera_rs_rx/src/axi_dma/` | DMA 驱动初始化、接收缓冲区、DMA 启动和中断处理。 |
| `camera_rs_rx/src/axi_gpio_cfg/` | FIFO 计数读取。 |
| `camera_rs_rx/src/sys_intr/` | GIC 与异常处理入口的初始化。 |
| `camera_rs_rx/src/platform*.h` | 原应用的平台相关接口声明和 Zynq 以太网配置。 |
| `camera_rs_rx/src/lscript.ld`、`Xilinx.spec` | 原应用的链接脚本与工具链配置。 |
| `camera_rs_rx/src/README.txt` | 原始 lwIP 示例模板说明，保留其原文；其中的示例 IP 和 iperf 操作不代表当前程序的实际配置。 |
| `platform_reference/system.mss` | 原 standalone BSP 的驱动与库选择，包括 lwIP 参数。 |
| `platform_reference/lwipopts.h` | 原 BSP 生成的 lwIP 编译选项参考。 |
| `platform_reference/xparameters.h` | 原 BSP 生成的硬件地址与中断号参考。 |

应用源码和参考配置均保持原文件内容、编码和换行。原工作区元数据、自动生成的驱动库、ELF、BOOT.BIN、bitstream 和 XSA 未复制。

## 与当前仓库 PL 工程的关系

该工作区原平台的硬件文件为 `camera_rx_wrapper/hw/design_1020_25M.xsa`，SHA-256 为：

```text
3780c51f03afea6be58909aa561e7cf16eb2484323eeb2c6a6551f8a4030a244
```

检查其内部 `camera_rx.hwh` 可见 RS 解码器 `rs_decoder_0`，UART IP 配置为 200 MHz 时钟、25 Mbaud。原工作区附带的烧录说明也将该 XSA 关联到 `7010_CAMERA_RS_RX/7010_camera_rs_rx` 工程。

当前仓库已同步本地 `7010_CAMERA_RS_RX/7010_camera_rs_rx` 的最新 PL：串行接收使用 `uart2fifo_v2`，配置为 **200 MHz / 25 Mbaud**，与原 PS 平台的串行速率一致。PL 包含 RS 解码器 `rs_decoder_0`、解码前的 `frame_cutter1`、解码后的 `frame_cutter`、参考 ROM、`ber_calculator`、`BECNT_UARTOUT_V2` 与 ILA。`BEout_0` 是误码统计串口输出，约束至 L14。

原 XSA 与当前 PL 仍属于不同硬件快照；构建时应从当前工程重新导出 XSA 并生成 BSP，避免沿用旧平台。当前同步保留本地 HDL 和 PS 软件业务逻辑。

已核对的主要接口如下：

| 接口 | 原 PS 平台 | 当前仓库接收端 PL |
| --- | --- | --- |
| AXI DMA 寄存器基地址 | `0x40400000` | `0x40400000` |
| AXI GPIO 寄存器基地址 | `0x41200000` | `0x41200000` |
| DMA 工作方式 | Simple DMA，S2MM 接收，MM2S 关闭 | 相同 |
| PS 以太网 | ENET0，`0xE000B000` | 相同 |
| RS 解码 | PL 中的 `rs_decoder_0` | PL 中的 `rs_decoder_0` |
| 串行接收参数 | 200 MHz IP 时钟、25 Mbaud | 200 MHz IP 时钟、25 Mbaud |

FIFO 计数阈值 300、DMA 接收长度 300 和 UDP 发送长度 239 均按原源码保留。当前 PL 的 `frame_cutter` 保留每帧前 239 字节并在最后一个有效字节置位 TLAST；DMA 接收缓冲区可容纳 300 字节。重建与上板时仍需核对 FIFO 计数单位、TLAST、DMA 实际完成长度与有效载荷。

## 在 Vitis 2020.2 中重建

1. 选定要运行的接收端 PL 工程，在 Vivado 中完成实现并导出匹配的 XSA。
2. 用该 XSA 创建新的 Vitis 平台，处理器选择 `ps7_cortexa9_0`，操作系统选择 standalone，并生成 BSP。
3. 添加 `lwip211` 库。原 BSP 使用 standalone 7.3、lwip211 1.3，stdin/stdout 均为 `ps7_uart_0`。原 `system.mss` 的主要网络设置为 `mem_size=524288`、`memp_n_pbuf=1024`、`n_rx_descriptors=512`、`pbuf_pool_size=16384`，并启用了 `lwip_dhcp` 与 `dhcp_does_arp_check`；当前应用本身配置静态 IP。
4. 创建应用并导入 `camera_rs_rx/src/` 全部文件。若由示例模板创建，请避免同时编译模板和仓库中的重复 `main.c` / UDP 实现。源文件包含子目录时保留相同层级，并让编译器搜索应用的 `src/` 根目录。
5. 用新 BSP 生成的头文件和库构建应用；`platform_reference/` 用于对照设置，不要作为 include 目录加入编译，以免使用旧地址或覆盖新平台配置。链接时核对 `lscript.ld` 的内存区域及 Cortex-A9 hard-float ABI 与新 BSP 一致。
6. 如需从 Flash 启动，用同一硬件版本生成 FSBL，并将 FSBL、对应 bitstream 和新应用 ELF 重新打包。

本次已校验 PS 源码与原工作区逐文件一致；尚未重新构建 Vitis 平台、编译该应用或进行上板验证。

## 网络配置

| 项目 | 当前源码值 |
| --- | --- |
| 开发板 IP | `192.168.253.103` |
| 子网掩码 | `255.255.255.0` |
| 网关 | `192.168.253.254` |
| 目标电脑 IP | `192.168.253.104` |
| 本地及目标 UDP 端口 | `5001` |
| 每次 UDP 发送长度 | 239 字节 |

地址配置在 `main.c` 和 `udp_perf_server.c` 中。只有收到足够的 PL 数据并完成 DMA 后，程序才发送 UDP 数据。原文件中的部分注释仍写着 1024 字节，应以当前常量与函数调用为准。

全部收录文件的来源和 SHA-256 见 [receiver_ps_source_manifest.json](receiver_ps_source_manifest.json)。
