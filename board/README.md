# 板端部署与接收

## 连接参数

| 项目 | 参数 |
| --- | --- |
| 主控 | XC7Z010CLG400-1，Cortex-A9 standalone |
| PL工具 | Vivado 2020.2 |
| PS工具 | Vitis 2020.2，standalone 7.3，lwip211 |
| OOK串行位速率 | 20 Mbps |
| PL逻辑时钟 | 200 MHz，每位10周期 |
| RS信息/码字长度 | 239 / 255 字节 |
| 板端IP | 192.168.253.103 |
| 电脑IP | 192.168.253.104 |
| 子网掩码 | 255.255.255.0 |
| 网关 | 192.168.253.254 |
| UDP端口 | 5001 |
| 统计串口 | 115200 bit/s |

## 生成PL与PS文件

1. 在Vivado中打开相应收发工程，完成IP生成、综合和实现，生成bitstream。
2. 导出包含bitstream的XSA。接收软件与接收PL使用同一份XSA。
3. 在Vitis中由该XSA创建Cortex-A9 standalone平台，加入lwip211库，stdin和stdout选择ps7_uart_0。
4. 创建空C应用，导入`src/ps/rx`全部源文件，保留子目录。将应用`src`根目录加入头文件搜索路径。
5. 使用平台生成的BSP头文件和库构建应用。`src/ps/platform_reference`保存原平台设置，供配置对照。
6. 需要Flash启动时，使用相同XSA创建Zynq FSBL，将FSBL、bitstream及接收应用ELF打包为BOOT.BIN。
7. `src/ps/tx_fsbl`保存发送侧FSBL代码，`fsbl_handoff.s`保留GNU汇编分支，可按小写后缀直接汇编。

接收侧GPIO通过`0x41200000`读取FIFO计数，DMA基址为`0x40400000`。程序在FIFO计数达到300时请求最多300字节的S2MM缓冲，PL在239字节有效载荷末尾给出TLAST。DMA完成后，PS发送239字节UDP信息帧。

## 运行UDP接收工具

电脑网卡设置为`192.168.253.104/24`，与接收板网口连接，允许本地UDP 5001端口。在项目根目录执行：

```text
python board/receive_udp.py --output data/capture/received.bin
```

接收1000个数据报后结束：

```text
python board/receive_udp.py --packets 1000 --timeout 10 --output data/capture/received.bin
```

默认每包239字节。工具按接收顺序连接保存全部UDP载荷，同时生成`received.bin.json`，记录数据报数量、字节数、长度异常数量、接收时长和SHA-256。结束持续接收时按Ctrl+C。

UDP工具用于信息帧接收与二进制记录。视频显示程序按业务数据格式读取接收载荷。

## DMA异常恢复

接收应用在DMA启动成功后才设置忙标志。错误中断关闭该通道中断并置错误标志，主循环复位DMA、清理完成标志并重新开放接收。复位超时会输出串口错误并退出应用，重新启动前检查PL数据流及TLAST。

## 构建和检查

`build/build_ps.tcl`提供接收应用的XSCT构建入口。执行前生成接收端XSA，并使用一个新的Vitis工作目录：

```text
xsct build/build_ps.tcl build/results/rx/rx_20mbps.xsa build/results/vitis_rx
```

主机侧PS逻辑测试位于`sim/ps`，可检查UDP长度处理、DMA启动和中断恢复逻辑。真实光链路的输出保存在`data/capture`。
