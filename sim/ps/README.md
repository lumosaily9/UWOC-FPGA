# PS主机逻辑测试

测试直接编译`src/ps/rx`中的C函数，使用本目录`stubs`替代Xilinx驱动和lwIP硬件接口。测试不访问板卡。

```text
python sim/ps/run_ps_tests.py --cc clang
```

Windows下还需LLVM链接器`lld.exe`，默认从编译器同目录寻找。也可通过`--linker`指定链接器的完整路径。Linux可使用PATH中的Clang或GCC。

| 测试 | 内容 |
| --- | --- |
| test_udp | 长度1、7、239、300及65507的发送缓冲与复制长度，空指针、无连接、申请失败、绑定失败和连接失败 |
| test_dma | 初始化、无效长度、启动失败、缓存刷新先于启动、完成后缓存失效、错误中断、复位恢复与超时 |
| test_main | 首次启动失败后重试、错误后清理忙标志、完成后发送239字节、不可恢复错误退出 |
| udp_loopback | 经本机UDP发送3个239字节数据报，核对717字节二进制输出与接收统计 |

输出写入`build/results/ps_tests`，包含编译及运行日志、UDP接收文件和`ps_test_results.json`。这些测试评价C控制流程与数据长度，PL、DMA控制器及网口硬件通过板端工程运行。
