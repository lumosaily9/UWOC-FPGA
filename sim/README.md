# RTL 仿真

主链路回归入口为`build/run_sim.py`。`legacy/`归档历史发射端激励，幅度域扩展激励位于`extensions/`，使用`build/run_extension_sim.py`运行。

在项目根目录运行：

```sh
python build/run_sim.py --stress --waves
```

Icarus Verilog 安装目录未加入 PATH 时，通过--tool-root指定实际安装根目录，安装于C:/tools/iverilog时运行：

```sh
python build/run_sim.py --tool-root C:/tools/iverilog --stress --waves
```

也可通过 `--iverilog`、`--vvp` 分别指定两个程序，或设置 `ICARUS_HOME`、`IVERILOG`、`VVP`。脚本将编译日志、运行日志及 `summary.json` 写入 `sim/results/`。Windows 旧版 Icarus 的工具路径含空格或中文时，脚本自动建立临时盘符映射，并在退出时释放。

## 测试项目

| Testbench | 检查内容 |
| --- | --- |
| `tb_ber.sv` | 每帧239字节的参考序列逐位统计，分别注入0、1、8及1912个错误比特 |
| `tb_frame_cutter.sv` | 连续输入两帧255字节，仅输出每帧前239字节，并检查TLAST、字节顺序与反压保持 |
| `tb_frame_boundary.sv` | 两帧各255字节的码字交付及帧结束标志，检查连续流与间断就绪 |
| `tb_serial_tx.sv` | 200 MHz逻辑时钟下每位10周期，44位同步段、255字节串行内容及帧末最高位完整保持 |
| `tb_serial_rx.sv` | 连续两帧44位同步段及255字节码字的恢复与TLAST，检查重新同步及短时反压 |
| `tb_serial_loopback.sv` | 发送器直接连接接收器，核对255字节首尾、顺序和帧结束标志 |

串行接收压力测试每80个逻辑周期最多暂停15个周期，恢复后继续消费已锁存的字节。该设置与20 Mbps串行输入的80周期字节间隔相配合。帧裁取压力测试按周期改变后级就绪信号，检查寄存输出在阻塞期间保持稳定。

## 输入数据与结果

`data/test/` 保存对应的参考字节、错误注入向量和预期计数。Testbench中的参考函数采用同一生成规则，字节值为 `(index * 37 + 1) & 255`。发送器最后一字节专门设置为 `0x80`，用于检查最后一位是否被提前清零。

`summary.json` 记录运行状态、各项测试输出以及被测RTL的SHA-256。`--waves` 生成串行发送和接收的VCD文件，可在波形查看器中观察50 ns位周期、同步识别和字节有效信号。
