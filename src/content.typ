#import "/global.typ": *

= Rust 异步编程
== 同步和异步
同步：多个操作之间相互关联，所以必须有明确的顺序。

异步：多个操作之间并不直接相关，故不必有明确顺序。

并发执行异步任务可以提高计算资源的使用效率，并行执行异步任务可以缩短任务的执行时间。

#pagebreak()

如何实现程序的异步执行？一个程序包含代码和数据两个部分，所以关键在于如何取舍代码和数据的切换：
- 进程：切换代码和数据；
- 线程：切换代码，不切换数据；
- 协程：不切换代码，不切换数据。

一些协程的实现方式：回调、Go Coroutines、actor、async/.await。

形成的文档：#link("https://ldq3.github.io/2024/05/24/%E5%BC%82%E6%AD%A5%E7%BC%96%E7%A8%8B/#more")[异步编程概述]。

== Future
Rust 实现了 async/.await 作为其异步编程模型。

future 是 Rust 的异步任务模型。从逻辑上看，一个 future 是一个状态机，future 会在给定的状态处等待；从底层实现上看，future 是一个实现了 Future 特征的结构体，这个结构体中包含状态、数据、其它 future 等内容，Future 特征包含 Executor 可见的 future 状态和一个 poll 方法两部分内容。

#pagebreak()

例如：

```Rust
let fut_one = /* ... */; // Future 1
let fut_two = /* ... */; // Future 2
async move {
    fut_one.await;
    fut_two.await;
}
```

#pagebreak()

经编译器处理后，自动生成一个结构体，并为其实现 Future 特征：
```Rust
struct AsyncFuture {
    fut_one: FutOne,
    fut_two: FutTwo,
    state: State,
}

// `async` 语句块可能处于的状态
enum State {
    AwaitingFutOne,
    AwaitingFutTwo,
    Done,
}

```

== 运行时
异步运行时（Runtime）是运行异步任务的机制，标准的 Rust 异步运行时包括以下三个部分：

- Executor：管理并调度执行 future，没有官方标准。

- Reactor：等待外设执行任务完成并唤醒对应 future，没有官方标准。

- Weaker：用于联系 Executor 和 Reactor 的结构，#link("https://docs.rs/async-std/latest/async_std/")[async_std] 为其广泛认可的标准。

形成的文档：#link("https://ldq3.github.io/2024/05/24/Rust%E4%B8%AD%E7%9A%84%E5%BC%82%E6%AD%A5%E7%BC%96%E7%A8%8B/#more")[Rust 中的异步编程]
；项目仓库：#link("https://github.com/ldq3/Rust_async")[Rust_async]（重构了 #link("https://github.com/ibraheemdev/too-many-web-servers/")[too-many-web-servers] 的异步运行时部分）。

= 基于 Rust 异步机制的驱动

== 嵌入式 Rust
与驱动开发紧密相关的是嵌入式领域。

嵌入式 Rust 的大部分资料基于 ARM 和 RISC-V 架构的芯片，其中 STM32 最常见。

学习资料：#link("https://docs.rust-embedded.org/")[Embedded Rust documentation]。

学习过程中，我主要使用的开发板是官方 QEMU 支持模拟的 #link("https://www.qemu.org/docs/master/system/arm/stm32.html")[STM32VLDISCOVERY] 和一块自己购买的 #link("http://www.st.com/en/evaluation-tools/stm32f3discovery.html")[STM32F3DISCOVERY]。

#pagebreak()

#figure(
  image("/resource/image/peripheral_access_levels.png", width: 70%),
  caption: [
    Abstraction levels of Rust embedded crate(STM32F3 for example).
  ],
) <glaciers>

#pagebreak()

直接操作 MCU 访问外设的方式是向特定的存储器地址写入数据，这些存储器地址被映射为相应的寄存器。在其之上，很多 crate 抽象出来更友好的接口：

- Micro-architecture Crate：这类 crate 给出了处理对应的处理器核心的常用例程，以及所有使用该特定类型处理器核心的 MCU 共有的任何外围设备。
- PAC：这类 crate 是对特定型号 MCU 所定义的各种寄存器的简单包装。
- HAL Crate：这类 crate 为特定型号 MCU 提供更友好的操作方式。
- Board Crate：这类 crate 为特定开发板提供。

#pagebreak()

#table(
  columns: 2,
  align: center,
  header(
    [*Crate*],
    [*Example*],
  ),

  [Micro-architecture Crate], [#link("https://crates.io/crates/cortex-m")[cortex-m]],

  [PAC], [#link("https://crates.io/crates/stm32f30x")[stm32f30x]],

  [HAL Crate], [#link("https://crates.io/crates/embedded-hal")[embedded-hal]],

  [Board Crate], [#link("https://crates.io/crates/stm32f3-discovery")[stm32f3-discovery]],
)

PAC 将直接与寄存器交互，这需要我们遵循每个外围设备在 MCU 的技术参考手册中给出的操作说明，例如 #link("https://www.stmcu.com.cn/Designresource/list/STM32F103/document/reference_manual")[STMCU reference manual]。

常用工具：交叉平台的目标文件处理工具链、烧录工具（Probe-rs 和 OpenOCD）、链接工具（ST-Link、J-Link）

形成文档：#link("https://ldq3.github.io/2024/06/15/%E7%9B%AE%E6%A0%87%E6%96%87%E4%BB%B6%E5%A4%84%E7%90%86%E5%B7%A5%E5%85%B7/")[目标文件处理工具]。

== Embassy
Embassy 是基于 Rust 的异步嵌入式应用框架，官方文档：#link("https://embassy.dev/book/")[Embassy Book]。

Embassy 的异步运行时部分，比较特别的地方是有四级执行器，最上层执行器定义于 embassy-executor/src/arch 目录下的对应架构的子模块中：
- Executor：控制处理器核心休眠和工作。

下面三层执行器定义于 embassy-executor/src/raw/mod.rs 中：
- Executor：对 SyncExecutor 的简单包装。
- SyncExecutor：包含两个重要的队列 run_queue 和 time_queue。在 run_queue 中的是准备就绪的任务。由于定时器触发的中断本身并不包含时间的信息，所以为了处理等待时间的任务，需要额外记录时间信息，于是就有了 time_queue 这样一个队列。该结构实现的 poll 方法为任务调度的核心逻辑。
- TaskStorage：由执行任务得到对应的 future，创建 waker 并将其包装为 context，并调用该 future 的 poll 方法。

#pagebreak()

Embassy 异步运行时的 Reactor 和 Waker 似乎并没有什么特别的地方。

wake 方法定义于 embassy-executor/src/raw/waker.rs 中。

#pagebreak()

Embassy HAL crate 在项目构建的过程中做了很多重要的工作，详情可以查看相应 Embassy HAL crate 项目根目录下的 build.rs 文件中的内容。

其中，绑定外设和引脚、处理 time-driver-xxxx features、通过使用 #link("https://docs.rs/stm32-metapac/")[`stm32-metapac`] 自动生成 memory.x 文件是我比较关注的内容。

#pagebreak()

尝试基于 Embassy 提供的可以使用 #link("https://github.com/embassy-rs/embassy/tree/main/embassy-time-driver/")[embassy-time-driver] 来实现自定义的时钟驱动，只需为自定义的结构体实现 Driver 特征，并调用 time_driver_impl 宏。

stm32 的通用定时器的主要组成部分是一个由一个可编程预分频器（programmable prescaler，PSC）驱动的一个16位自动重装载的计数器。

在STM32系统中，定时器的时钟源为内部时钟时，其频率一般都比较高，如果我们需要更长时间的定时间隔，那么就需要 PSC 对时钟进行分频处理。使用定时器预分频器和 RCC 时钟控制器的预分频器，脉冲长度和波形周期可以调制从几微秒到几毫秒不等的时间。

#pagebreak()

和其他外设一样，我们在使用这个定时器之前需要初始化它。定时器初始化将涉及两个步骤：启动定时器，然后进行配置。

启动定时器很简单：我们只需将 TIM6EN 位设置为 1。这个位于 RCC 寄存器块的 APB1ENR 寄存器中。



不启用 HAL 的 time-driver- feature，调用自己时钟驱动的 init 方法。

项目仓库：#link("https://github.com/ldq3/stm32f303vct-time-driver")[stm32f303vct-time-driver]（物理开发板的时钟驱动）

== QEMU
QEMU 的问题是缺少很多设备，官方 QEMU stm32 支持和缺失的设备列表在网页 #link("https://www.qemu.org/docs/master/system/arm/stm32.html")[STMicroelectronics STM32 boards] 中给出，其中比较关键的是缺少 RCC 和 RTC。

QEMU 的仿真通常不会试图模拟以兆赫兹频率发送脉冲的实际时钟线（这样做效率极低）。实际上，当虚拟机程序对定时器设备进行编程时，定时器设备的模型会设置一个内部 QEMU 定时器，在适当的持续时间后触发（处理程序随后会拉高中断线或执行其他仿真硬件行为所需的操作）。持续时间是根据虚拟机写入设备寄存器的数值计算的，并附带一个时钟频率的设定值。

QEMU 没有处理可编程时钟分频器或像"时钟树"这样的基础设施（虽然可以添加，但目前还没有人这样做）。定时器设备通常要么使用硬编码的频率，要么可以通过 QOM 属性由创建它们的板或 SoC 模型代码设置频率。（参考链接：#link("https://stackoverflow.com/questions/56853507/timer-supply-to-cpu-in-qemu")[Timer supply to CPU in QEMU]）

由于无法直接使用 Embassy HAL crate，于是参照 embassy-stm32，基于 PAC 和 Micro-architecture Crate 来实现支持官方 qemu stm32 的 HAL。

项目仓库：#link("https://github.com/ldq3/embassy-stm32-qemu/")[embassy-stm32-qemu]（To Be Continue……）

= 总结
在训练营中学到了很多，在同老师和同学们的分享交流中能更好地看清自己的想法，收获很大。补充了很多软硬件的知识，也锻炼了自己使用工具、整理信息和知识的能力。

But, job is not finished……

最后，再给大家推荐一下 Typst（官方文档：#link("https://typst.app/docs/")[Typst
Documentation]，及其中文版：#link("https://typst-doc-cn.github.io/docs/")[Typst 中文文档]）。

本文稿使用 Typst 撰写，项目仓库：#link("/summary_of_OS_camp/")[summary_of_OS_camp]。