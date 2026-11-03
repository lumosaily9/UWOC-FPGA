# 水下无线光通信智能收发终端

本工程实现20 Mbps OOK无线光通信收发，包含接收端PS程序、RTL仿真、构建脚本和作品报告。主控为XC7Z010CLG400-1，开发环境为Vivado / Vitis 2020.2。

## 目录

```text
uwoc_fpga/
├── README.md
├── src/
│   ├── pl/tx/                 # 发射端Vivado工程
│   ├── pl/rx/                 # 接收端Vivado工程
│   ├── pl/extensions/         # 幅度域FFE、选样、FIFO与时隙控制
│   ├── ip_repo/               # 自定义PL IP
│   └── ps/                    # 接收程序、启动程序与BSP配置
├── sim/                       # 主链路与扩展模块测试、仿真结果
├── build/                     # 工程构建、源码检查与回归脚本
├── board/                     # 上板步骤、UDP接收与采集输出
├── data/                      # ROM序列、测试向量与参数配置
├── skill/
│   └── README.md              # 调试经验、验证方法和使用边界
└── report/                    # 作品报告、可编辑框图与大模型协作记录
```

文件路径采用英文小写、数字、下划线与连字符，说明文件使用常规的README.md名称。中文只用于正文与代码注释。解压后保留目录之间的相对位置。

## 参数与处理流程

| 项目 | 配置 |
| --- | --- |
| 调制与线速 | NRZ-OOK，20 Mbps |
| 码元率与周期 | 20 MBd，50 ns |
| PL时钟 | 200 MHz，10个逻辑周期/位 |
| 信道编码 | RS(255,239)，8位符号 |
| 同步段 | 44 bit |
| 有效信息 | 每帧239字节 |
| 误码统计串口 | 115200 bit/s |
| 板端IP | 192.168.253.103 |
| 电脑IP与接收端口 | 192.168.253.104:5001 |

发送通路读取239字节参考序列，经过RS编码、FIFO和串行发送输出。接收通路依次完成同步识别、字节恢复、255字节码字组帧、RS译码和239字节信息提取。PS读取FIFO水位，使用DMA将信息帧写入DDR，再通过UDP交付计算机。参考序列支路统计RS译码后的信息比特误码。

幅度域扩展模块位于`src/pl/extensions/`，使用120 MSa/s、每码元6个样点的仿真配置，包含选样、五抽头定点FFE、弹性FIFO和半双工时隙控制。对应测试与主链路测试分别运行。

## 环境准备

1. 安装Vivado 2020.2，选择Zynq-7000器件支持，启用RS Encoder / Decoder IP所需许可。
2. 安装Vitis 2020.2及其XSCT工具，接收端软件使用Cortex-A9 standalone和lwip211。
3. 安装Python 3.10或以上版本和Icarus Verilog，将`iverilog`与`vvp`加入PATH。也可通过参数传入工具路径。
4. 将工程解压到固定工作目录，在`uwoc_fpga`根目录运行以下命令。

## 源码与路径检查

```sh
python build/check_sources.py
python build/check_package.py
```

检查工程引用、ROM路径、20 Mbps参数、命名规则及Python脚本语法。结果写入`build/results/`。

## RTL仿真

运行主链路自定义模块回归：

```sh
python build/run_sim.py
```

运行幅度域扩展回归：

```sh
python build/run_extension_sim.py
```

Icarus未加入PATH时，可设置环境变量`IVERILOG`、`VVP`指向对应程序，也可使用`--tool-root`指定包含`bin/`的工具根目录。主链路日志、统计和仿真生成物位于`sim/results/`。扩展日志位于`sim/results/extensions/`，扩展生成物位于`build/results/extension_sim/`。主链路测试检查串行位节拍、同步段、帧裁取和误码计数，扩展测试检查幅度映射、六相位、FIFO、定点FFE及收发时隙。

包含反压与串行波形的完整主链路回归：

```sh
python build/run_sim.py --stress --waves
```

PS函数和UDP接收工具的主机测试：

```sh
python sim/ps/run_ps_tests.py --cc clang
```

## PL构建

在已配置Vivado命令环境的终端中运行：

```sh
vivado -mode batch -source build/build_project.tcl -tclargs tx validate 4
vivado -mode batch -source build/build_project.tcl -tclargs rx validate 4
vivado -mode batch -source build/build_project.tcl -tclargs tx bitstream 4
vivado -mode batch -source build/build_project.tcl -tclargs rx bitstream 4
```

`validate`检查Block Design，`synth`完成综合，`impl`完成实现，`bitstream`生成下载文件并导出XSA。每个角色的日志、时序与利用率报告写入`build/results/tx/`或`build/results/rx/`。

打开图形工程：

```sh
vivado -mode gui -source build/open_project.tcl -tclargs tx
vivado -mode gui -source build/open_project.tcl -tclargs rx
```

## PS构建与上板

按`board/README.md`使用PL构建的XSA创建Vitis平台，构建接收端应用和启动程序，再配置硬件。自动构建脚本为`build/build_ps.tcl`，参数以该脚本开头的用法说明为准。

接收端应用使用AXI DMA的S2MM通道，DMA缓冲容量为300字节，有效信息为239字节。网口配置位于`src/ps/rx/main.c`和`src/ps/rx/udp_perf_server.c`。

计算机网口设为`192.168.253.104/24`后，接收并保存数据：

```sh
python board/receive_udp.py --bind 192.168.253.104 --port 5001 --output board/results/received.bin
```

按Ctrl+C结束接收。二进制数据与统计JSON保存在指定位置。误码串口接`BEout_0`，按115200 bit/s读取。

## 文档与复现记录

- `report/technical_report.docx`：作品报告。
- `report/flow_diagrams.pptx`：可编辑流程图。
- `report/ai_collaboration.md`：系统设计、FPGA调试及验证中的人机协作记录。
- `skill/README.md`：工程经验提炼与验证记录。
- `data/config/project.json`：链路、网络和幅度域扩展参数。
- `data/manifests/package_manifest.json`：代码来源、文件清单和SHA-256。


