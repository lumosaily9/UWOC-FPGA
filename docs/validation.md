# 当前同步版本验证记录

验证日期：2026-11-02。使用本机 **Vivado 2020.2，Build 3064766**，在仓库临时副本上执行，原工作区工程未作修改。

## 静态检查

- `docs/source_manifest.json` 的 98 项文件 SHA-256 全部匹配。
- 接收端 PS 的 17 项文件与原工作区及来源清单 SHA-256 匹配。
- 8 个自定义 IP 的 `component.xml` 引用文件均存在。
- 两个 XPR 的源文件、Block Design/XCI 的 COE 引用均指向仓库内存在的文件。
- 当前顶层封装包含 BD 的外部信号，接收端包括 `BEout_0`。

## Vivado 检查

对两端分别执行仓库的 `scripts/open_project.tcl`、`report_ip_status` 与 `validate_bd_design`。

| 工程 | 打开工程及 BD | validate_bd_design | IP 状态 |
| --- | --- | --- | --- |
| TX | 通过 | 通过 | 8 个 Up-to-date |
| RX | 通过 | 通过 | 20 个 Up-to-date |

两端检查均无 ERROR。首次打开源码仓库时，Vivado 提示生成目录和历史运行输出不存在；这些输出不纳入 Git，需要重新生成。

仍存在以下 BD 警告：

- `BD 41-926`：发射端 `fifo2uart_v2_0/s_axis`、接收端 `frame_cutter_0/s_axis_input` 的 `LAYERED_METADATA` 由连接的 IP 传播，自定义 IP 不接受参数变更。
- `BD 41-927`：`rom2rs`、`fifo2uart_v2`、`ber_calculator`、`uart2fifo_v2`、`BECNT_UARTOUT_V2` 的时钟接口 `FREQ_HZ` 属性由连接传播为 200 MHz，自定义 IP 不接受参数变更。当前有时钟参数的对应 BD 单元已配置 `CLK_FREQ=200000000`；这些警告涉及 IP 接口元数据，仍需在进一步构建时核对。

本次同步保留原 IP 封装与 HDL 业务逻辑。`report_ip_status` 中 RS IP 的许可列为 `Hardware_E`，实际生成与部署所需许可应在目标环境中核对。

## 未覆盖范围

尚未重新执行综合、实现、bitstream 生成、完整仿真、Vitis 应用构建或上板测试。工程打开及 BD 验证通过不代表时序或链路功能已验证。

归档的 `tb_RA_TX.v` 仍连接旧版顶层的 `clk_in1_0` 与 `reset_in_0`；当前顶层使用 Zynq PS 接口，因此该 testbench 需要按当前设计调整后才能运行。
