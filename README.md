# UWOC-FPGA

水下无线光通信（UWOC）FPGA 发射端与接收端工程，目标器件为 **Xilinx Zynq-7000 XC7Z010CLG400-1**。

PL 工程来自 `7010-RA-TX/`（发射端）和 `7010_CAMERA_RS_RX/`（接收端），工程文件记录的工具版本为 **Vivado 2020.2**。接收端 PS 应用另从 `Enbedded_Vitis/camera_rs_rx_` 收录，运行于 Cortex-A9 的 standalone 环境，使用 lwIP 发送 UDP 数据。

接收端 PL 包含 RS 解码器，PS 应用负责 DMA 接收及 UDP 转发。PS 工作区原先基于该接收端系列的 **25 Mbaud** 硬件导出构建，本仓库收录的 PL 源码配置为 **10 Mbaud**；两者主要 PS 接口一致，重建时应以当前 PL 重新导出的 XSA 生成平台。详情见 [接收端 PS 说明](docs/receiver_ps.md)。

## 目录

```text
UWOC-FPGA/
├── 7010-RA-TX/
│   └── 7010-RA-TX/
│       ├── 7010-RA-TX.xpr
│       ├── 7010-RA-TX.srcs/   # Block Design、IP 配置、HDL、约束和仿真源码
│       ├── data/              # ROM 初始化 COE 文件
│       └── vitis/7010-ra-tx/src/  # 原工程的 FSBL 源码
├── 7010_CAMERA_RS_RX/
│   └── 7010_camera_rs_rx/
│       ├── 7010_camera_rs_rx.xpr
│       ├── 7010_camera_rs_rx.srcs/
│       └── vitis/
│           ├── camera_rs_rx/src/  # 接收端 PS 应用：DMA 接收、UDP 转发
│           └── platform_reference/  # 原平台的 BSP 设置和硬件参数参考
├── ip_repo/                   # 两个工程实际使用的五个自定义 IP
├── scripts/open_project.tcl   # 打开工程并设置仓库内的 IP/COE 路径
└── docs/                      # PS 使用说明、文件来源与 SHA-256 校验信息
```

## 各目录用途

| 目录 | 大概用途 |
| --- | --- |
| `7010-RA-TX/` | 发射端的归档目录，内部 `7010-RA-TX/` 是实际 Vivado 工程根目录。 |
| `7010-RA-TX/7010-RA-TX/7010-RA-TX.srcs/` | 发射端 PL 设计：`sources_1/bd/design_1/` 保存 Block Design 和各 IP 的 XCI 配置；`sources_1/imports/` 保存顶层封装；`constrs_1/new/` 保存管脚约束；`sim_1/new/` 保存 testbench。 |
| `7010-RA-TX/7010-RA-TX/data/` | 两份原始 ROM 初始化 COE 数据，供发射端工程使用。 |
| `7010-RA-TX/7010-RA-TX/vitis/7010-ra-tx/src/` | 发射端 FSBL 源码，包括启动、硬件初始化和加载相关代码。 |
| `7010_CAMERA_RS_RX/` | 接收端的归档目录，内部 `7010_camera_rs_rx/` 是实际 Vivado 工程根目录，并存放接收端 PS 应用。 |
| `7010_CAMERA_RS_RX/7010_camera_rs_rx/7010_camera_rs_rx.srcs/` | 接收端 PL 设计：`sources_1/bd/camera_rx/` 保存串行接收、FIFO、RS 解码、帧裁剪、DMA、GPIO 和 Zynq PS 的连接与 IP 配置；`sources_1/imports/` 保存顶层封装；`constrs_1/new/` 保存管脚约束。 |
| `7010_CAMERA_RS_RX/7010_camera_rs_rx/vitis/camera_rs_rx/src/` | 接收端 PS 应用源码。`main.c` 初始化外设并调度 DMA/UDP；`udp_perf_server.c` 将接收到的数据通过以太网发送给电脑；其余文件提供接口声明、平台配置和链接脚本。 |
| `…/camera_rs_rx/src/axi_dma/` | AXI DMA 配置、S2MM 数据接收及 DMA 完成/错误中断处理。 |
| `…/camera_rs_rx/src/axi_gpio_cfg/` | 配置 AXI GPIO 输入，并读取 PL 侧 FIFO 中的数据计数。 |
| `…/camera_rs_rx/src/sys_intr/` | 初始化 Cortex-A9 的 GIC 中断控制器，注册并使能异常入口。 |
| `7010_CAMERA_RS_RX/7010_camera_rs_rx/vitis/platform_reference/` | 原 PS 平台的 `system.mss`、`lwipopts.h` 和 `xparameters.h` 快照，用于参考 BSP 库设置、网络选项和硬件地址；新平台应自行生成这些配置。 |
| `ip_repo/rom2rs/` | 发射端自定义 IP，从 ROM 读取数据并向 RS 编码数据通路提供输入。 |
| `ip_repo/fifo_count/` | 发射端自定义流控 IP，根据 FIFO 数据计数控制 AXI Stream 的 ready 信号。 |
| `ip_repo/fifo2uart/` | 发射端自定义 IP，将 FIFO/AXI Stream 数据串行发送。 |
| `ip_repo/uart2fifo_half_forcamera/` | 接收端自定义 IP，将串行输入转换为 AXI Stream 数据，送入后续 FIFO 与 RS 解码通路。 |
| `ip_repo/frame_cutter/` | 接收端自定义帧裁剪 IP，保留每帧前 239 字节并产生 TLAST，丢弃帧中剩余部分。 |
| `ip_repo/*/xgui/` | 各自定义 IP 在 Vivado IP Catalog 中的参数界面 Tcl 文件；同级 `component.xml` 描述 IP 的接口与源文件。 |
| `scripts/` | 工程打开脚本，自动设置当前仓库的 IP 路径及发射端 COE 路径。 |
| `docs/` | 接收端 PS 的工作流程、平台重建方法和硬件版本差异，以及原工程/新增 PS 文件的来源和校验记录。 |

## 打开工程

建议使用 **Vivado 2020.2**。克隆或下载整个仓库，保持以上目录结构。

在 Vivado 的 Tcl Console 中执行，路径改为本机仓库位置：

```tcl
# 发射端
set argv {tx}
source {C:/path/to/UWOC-FPGA/scripts/open_project.tcl}
```

```tcl
# 接收端（在另一个 Vivado 会话中打开，或先关闭当前工程）
set argv {rx}
source {C:/path/to/UWOC-FPGA/scripts/open_project.tcl}
```

也可以通过命令行打开：

```text
vivado -mode gui -source scripts/open_project.tcl -tclargs tx
vivado -mode gui -source scripts/open_project.tcl -tclargs rx
```

脚本会设置本仓库的 `ip_repo`，更新 IP Catalog，打开 Block Design，并为发射端 ROM 设置本地 COE 路径。随后在 Vivado 中执行 **Generate Output Products**、综合、实现及 Generate Bitstream。也可以直接打开对应的 `.xpr`，其工程与 IP 仓库引用已经改为仓库内的相对路径。

发射端使用 `rom2rs`、`fifo_count`、`fifo2uart` 自定义 IP；接收端使用 `uart2fifo_half_forcamera` 和 `frame_cutter`。Xilinx 标准 IP 由 Vivado 安装提供。Reed-Solomon Encoder/Decoder IP 的许可证要求以 Vivado 的 IP 状态和许可证检查结果为准。

## 软件源码

发射端保留 `vitis/7010-ra-tx/src/` 中的原始 FSBL 源码。原目录 `vitis/` 与 `vitis_/` 的应用源码逐文件相同，因此只收录一份。Vitis 工作区元数据、自动生成的 BSP、编译输出和硬件导出文件未收录。

接收端应用位于 `7010_CAMERA_RS_RX/7010_camera_rs_rx/vitis/camera_rs_rx/src/`。主要流程为：通过 AXI GPIO 读取 FIFO 计数，计数达到 300 时启动 DMA 接收；DMA 完成后从缓冲区取 239 字节，通过 UDP 发送给电脑。开发板静态 IP 为 `192.168.253.103/24`，目标电脑为 `192.168.253.104:5001`，网关为 `192.168.253.254`。

使用软件工程时，在 Vitis 2020.2 中基于目标硬件重新导出的 XSA 创建平台，选择 `ps7_cortexa9_0` / standalone。接收端启用 `lwip211`，参考 `platform_reference/` 中的原配置，再导入应用源码并重新构建；发射端则创建 FSBL 应用并导入对应源码。接收端应用不属于 FSBL，`src/README.txt` 是原始 lwIP 示例说明，实际行为及 IP 地址以当前源码和 [接收端 PS 说明](docs/receiver_ps.md) 为准。

## 整理与验证范围

- 保留 HDL、Block Design、XCI 配置、XDC 约束、发射端 testbench、自定义 IP 包与相关软件源码。
- 从发射端原工程的 `ip_user_files/mem_init_files/` 恢复两份原始 COE 文件；它们与原仿真目录内的同名文件一致。
- 只调整副本的工程位置、IP 仓库及 COE 引用，并清理工程中记录的旧导入路径和自动增量目录。原始工程保持不变。
- 已检查工程源文件、五个自定义 IP 的文件引用、COE 路径与来源校验值；自定义 IP 的 HDL 与原工程生成目录内对应的源码快照一致。新增接收端 PS 源码和三份 BSP 参考文件均按原始字节复制，并检查了主要硬件接口与源文件完整性。
- 本次整理环境未提供 Vivado/Vitis，**尚未重新执行综合、实现、仿真或上板验证**。请在具备工具和相应 IP 许可的环境中完成这些检查。

`docs/source_manifest.json` 记录当前发射端、RS 接收端及自定义 IP 文件的原始相对位置、原始 SHA-256、整理后 SHA-256，以及是否因路径迁移而变化。`docs/receiver_ps_source_manifest.json` 单独记录新增接收端 PS 文件，以及原硬件导出文件的 SHA-256。缓存、日志、仿真输出、bitstream、XSA 等生成文件通过 `.gitignore` 排除。

原文件中的 Xilinx 等第三方版权与许可声明予以保留；本次整理未新增项目级开源许可证。
