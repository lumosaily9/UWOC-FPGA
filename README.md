# UWOC-FPGA

水下无线光通信（UWOC）FPGA 发射端与接收端工程，目标器件为 **Xilinx Zynq-7000 XC7Z010CLG400-1**。

工程来自 `7010-RA-TX/`（发射端）和 `7010-CAMERA-RX/`（接收端），工程文件记录的工具版本为 **Vivado 2020.2**。

## 目录

```text
UWOC-FPGA/
├── 7010-RA-TX/
│   └── 7010-RA-TX/
│       ├── 7010-RA-TX.xpr
│       ├── 7010-RA-TX.srcs/   # Block Design、IP 配置、HDL、约束和仿真源码
│       ├── data/              # ROM 初始化 COE 文件
│       └── vitis/7010-ra-tx/src/  # 原工程的 FSBL 源码
├── 7010-CAMERA-RX/
│   └── 7010_camera_rx/
│       ├── 7010_camera_rx.xpr
│       ├── 7010_camera_rx.srcs/
│       └── ps7_init*          # 原工程附带的 PS 初始化文件
├── ip_repo/                   # 两个工程实际使用的四个自定义 IP
├── scripts/open_project.tcl   # 打开工程并设置仓库内的 IP/COE 路径
└── docs/source_manifest.json  # 来源与 SHA-256 校验信息
```

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

发射端使用 `rom2rs`、`fifo_count`、`fifo2uart` 自定义 IP；接收端使用 `uart2fifo_v2`。Xilinx 标准 IP 由 Vivado 安装提供。发射端使用的 Reed-Solomon Encoder IP 是否需要额外许可证，请以 Vivado 的 IP 状态和许可证检查结果为准。

## 软件源码

发射端保留 `vitis/7010-ra-tx/src/` 中的原始 FSBL 源码。原目录 `vitis/` 与 `vitis_/` 的应用源码逐文件相同，因此只收录一份。Vitis 工作区元数据、自动生成的 BSP、编译输出和硬件导出文件未收录。

使用软件工程时，在 Vitis 2020.2 中基于重新导出的 XSA 创建平台与 standalone/FSBL 应用，再导入这些源码，并使用匹配当前硬件的 BSP 与 PS 初始化配置。此目录中的 `main.c` 是 FSBL，接收端原目录未包含单独的 Vitis 应用工程。

## 整理与验证范围

- 保留 HDL、Block Design、XCI 配置、XDC 约束、发射端 testbench、自定义 IP 包与相关软件源码。
- 从发射端原工程的 `ip_user_files/mem_init_files/` 恢复两份原始 COE 文件；它们与原仿真目录内的同名文件一致。
- 只调整副本的工程位置、IP 仓库及 COE 引用，并清理工程中记录的旧导入路径和自动增量目录。原始工程保持不变。
- 已检查工程源文件、四个自定义 IP 的文件引用、COE 路径与来源校验值；自定义 IP 的 HDL 与原工程生成目录内对应的源码快照一致。
- 本次整理环境未提供 Vivado/Vitis，**尚未重新执行综合、实现、仿真或上板验证**。请在具备工具和相应 IP 许可的环境中完成这些检查。

`docs/source_manifest.json` 记录每个收录文件的原始相对位置、原始 SHA-256、整理后 SHA-256，以及是否因路径迁移而变化。缓存、日志、仿真输出、bitstream、XSA 等生成文件通过 `.gitignore` 排除。

原文件中的 Xilinx 等第三方版权与许可声明予以保留；本次整理未新增项目级开源许可证。
