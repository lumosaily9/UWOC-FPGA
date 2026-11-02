# UWOC-FPGA

基于 **Xilinx Zynq-7000 XC7Z010CLG400-1** 的水下无线光通信（UWOC）FPGA 发射端与接收端工程，使用 **Vivado / Vitis 2020.2**。

当前版本同步自本地 `7010-RA-TX/` 和 `7010_CAMERA_RS_RX/` 对应工程。收发两端串行 IP 均配置为 **200 MHz 时钟、25 Mbaud**；接收端包含 RS 解码、DMA/UDP 转发，以及误码统计和串口输出通路。接收端 PS 源码来自 `Enbedded_Vitis/camera_rs_rx_`，运行于 Cortex-A9 standalone 环境。

## 当前设计

| 项目 | 发射端 | 接收端 |
| --- | --- | --- |
| Vivado 工程 | `7010-RA-TX/7010-RA-TX/7010-RA-TX.xpr` | `7010_CAMERA_RS_RX/7010_camera_rs_rx/7010_camera_rs_rx.xpr` |
| Block Design | `design_1` | `camera_rx` |
| 串行 IP | `fifo2uart_v2` | `uart2fifo_v2` |
| IP 时钟 / 波特率 | 200 MHz / 25 Mbaud | 200 MHz / 25 Mbaud |
| PL 外部信号 | `txd_0`，Y19，LVCMOS33 | `rx_0`，Y16；`BEout_0`，L14；LVCMOS33 |
| ROM 初始化 | `data/dds_239x8b_wave.coe` | `data/dds_239x8b_wave.coe` |

发射端通过 `rom2rs`、RS Encoder、FIFO 和 `fifo2uart_v2` 产生串行数据。接收端使用 `uart2fifo_v2`、`frame_cutter1` 和 RS Decoder 处理接收数据，再由 `frame_cutter` 提取有效数据，送往 DMA 与误码统计通路。`ber_calculator` 使用参考 ROM 统计误码，`BECNT_UARTOUT_V2` 将统计结果从 `BEout_0` 输出；此统计串口默认波特率为 **115200**，与光通信数据通路的 25 Mbaud 分开配置。工程同时保留 ILA 调试配置。

## 目录

```text
UWOC-FPGA/
├── 7010-RA-TX/7010-RA-TX/
│   ├── 7010-RA-TX.xpr
│   ├── 7010-RA-TX.srcs/      # BD、XCI、顶层封装、约束、原 testbench
│   ├── data/                 # ROM 初始化 COE
│   └── vitis/7010-ra-tx/src/  # 发射端 FSBL 源码
├── 7010_CAMERA_RS_RX/7010_camera_rs_rx/
│   ├── 7010_camera_rs_rx.xpr
│   ├── 7010_camera_rs_rx.srcs/
│   ├── data/                 # 接收端参考 ROM 与工程引用的 COE
│   └── vitis/
│       ├── camera_rs_rx/src/  # DMA 接收、UDP 转发
│       └── platform_reference/  # BSP 设置与硬件参数参考
├── ip_repo/                  # 当前设计使用的 8 个自定义 IP
├── scripts/open_project.tcl  # 配置仓库内 IP 和 ROM 路径
└── docs/                     # PS 说明、来源与 SHA-256 清单
```

| 自定义 IP 目录 | 用途 |
| --- | --- |
| `ip_repo/rom2rs/` | 从 ROM 读取待发送数据。 |
| `ip_repo/fifo_count/` | 根据 FIFO 计数控制数据流。 |
| `ip_repo/fifo2uart_v2/` | 发射端串行输出。 |
| `ip_repo/uart2fifo_v2/` | 将串行输入转换为流数据。 |
| `ip_repo/frame_cutter1/` | 接收端 RS 解码前的帧处理，按源码计数至第 255 字节。 |
| `ip_repo/frame_cutter/` | 提取每帧前 239 字节并产生 TLAST。 |
| `ip_repo/ber_calculator/` | 与 ROM 参考数据比较并统计误码。 |
| `ip_repo/BECNT_UARTOUT_V2/` | 累计误码统计并通过串口输出。 |

各 IP 的 `component.xml` 与 `xgui/` 文件分别保存接口/源文件定义和 Vivado 参数界面。旧版 `fifo2uart` 与 `uart2fifo_half_forcamera` 已随设计更新替换。

## 打开工程

克隆整个仓库并保持目录结构，建议使用 **Vivado 2020.2**。

```sh
git clone https://github.com/lumosaily9/UWOC-FPGA.git
cd UWOC-FPGA
```

在 Vivado Tcl Console 中打开发射端：

```tcl
set argv {tx}
source {C:/path/to/UWOC-FPGA/scripts/open_project.tcl}
```

在另一个 Vivado 会话中打开接收端，或先关闭当前工程：

```tcl
set argv {rx}
source {C:/path/to/UWOC-FPGA/scripts/open_project.tcl}
```

也可在已配置 Vivado 环境的命令行执行：

```sh
vivado -mode gui -source scripts/open_project.tcl -tclargs tx
vivado -mode gui -source scripts/open_project.tcl -tclargs rx
```

脚本设置仓库内 `ip_repo`，更新 IP Catalog，打开 Block Design，并为两端 ROM 设置本地 `dds_239x8b_wave.coe`。随后执行 **Validate Design → Generate Output Products → 综合 → 实现 → Generate Bitstream**。`.xpr` 内的 IP、顶层封装和 COE 引用也已改为仓库内路径。

Xilinx 标准 IP 由 Vivado 安装提供；RS Encoder/Decoder 的许可证要求以本机 IP 状态检查结果为准。仓库收录的发射端 `tb_RA_TX.v` 为原有仿真源码，其 `clk_in1_0` / `reset_in_0` 连接对应旧版顶层；运行仿真前需按当前 Zynq PS 顶层接口调整 testbench。

## 软件源码

发射端 `vitis/7010-ra-tx/src/` 保留原 FSBL 源码。接收端应用位于 `7010_CAMERA_RS_RX/7010_camera_rs_rx/vitis/camera_rs_rx/src/`：通过 AXI GPIO 读取 FIFO 计数，达到 300 时启动 DMA，完成后取 239 字节通过 lwIP RAW UDP 发给电脑。PS 软件不执行 RS 解码。

| 网络配置 | 当前源码值 |
| --- | --- |
| 开发板 IP / 子网掩码 | `192.168.253.103` / `255.255.255.0` |
| 目标电脑 IP / UDP 端口 | `192.168.253.104:5001` |
| 网关 | `192.168.253.254` |

在 Vitis 2020.2 中，用当前 PL 重新导出的 XSA 创建 `ps7_cortexa9_0` / standalone 平台。接收端启用 `lwip211`，参考 `platform_reference/` 的配置，再导入应用源码并构建；发射端创建 FSBL 应用并导入对应源码。BSP 参考文件来自原平台，应使用新平台生成的头文件和库进行编译。详细流程见 [接收端 PS 说明](docs/receiver_ps.md)。

## 同步与验证

- 本次同步更新两个对应 PL 工程的 BD、XCI、管脚约束、当前顶层封装及 8 个自定义 IP；两端均使用 25 Mbaud 配置，接收端包含误码统计通路。
- 将原工程引用的 COE 收录到各自 `data/`，同时修正 IP、ROM 和顶层文件路径；保留 HDL 原始字节、编码、版权与业务逻辑。
- 已校验文件 SHA-256、自定义 IP 文件引用、工程源文件及 ROM 路径和顶层端口。两端均通过 Vivado 2020.2 工程打开与 Block Design 验证；自定义 IP 仍有接口元数据和频率传播警告，详情见 [验证记录](docs/validation.md)。
- 尚未重新执行综合、实现、完整仿真、Vitis 应用构建或上板验证。

`docs/source_manifest.json` 记录当前 PL、IP 和发射端软件文件的本地来源及整理前后 SHA-256；`docs/receiver_ps_source_manifest.json` 记录接收端 PS 文件与原硬件导出信息。缓存、日志、生成的 IP 产品、bitstream、XSA、BSP 和编译输出由 `.gitignore` 排除。

原文件中的 Xilinx 等第三方版权与许可声明予以保留；本仓库未新增项目级开源许可证。
