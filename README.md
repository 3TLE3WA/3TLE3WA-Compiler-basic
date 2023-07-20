# 3TLE3WA-Compiler-basic

the compiler implemented basic methods

# 整体架构说明

```
          +-----------+
          | sysy file |
          +-----------+
                |
                v
  +------------------------------+
  | antlr4 pre genernated parser |
  +------------------------------+
                |
                |
                v
      +----------------------+
      | frontend gen llvm ir |
      +----------------------+
                |
                |
                v
        +-----------------+
        | pass on llvm ir | <--- cfg node now using shared_ptr and have many copy/destroy
        +-----------------+      while optimizing
                |                this consumes most of compile time
                |
                v
      +---------------------+
      | backend distributer | <--- the backend only take around 0.8% of compile time
      +---------------------+      no need for parallelization
          |     |     |  
          |     |     | <--- compile tasks allocated to multi-threads if parallel issued
          |     |     |      serialize issue or parallel issue
          |    ...   ...
          |
          v
  +-------------------+
  | risc-lang ir      |
  | just Uop and VReg |  <-- schedule on ir, assign register, plan stack map
  +-------------------+
            |
            |
            |
            v            +--------------+
      +-------------+    | other thread |
      |  riscv asm  |    +--------------+
      +-------------+           v
            |                   v
            |                   |                  +--------------+
            +-------------------+------------- <<< | other thread |
                                |                  +--------------+
                                |
                                | <--- do trick on generation
                                |
                                v
                +---------------------------------+
                | asm optimization and generation |
                +---------------------------------+
                                |
                                | <--- schedule on asm and reduce redundant codes
                                v
                          +----------+
                          | asm file |
                          +----------+
```

# 后端进一步优化说明

## 寄存器分配机制

目前的寄存器分配机制是先使用虚拟资源分配，然后对虚拟资源进行评估，最后定夺如何分配寄存器。

该方法借鉴于操作系统的虚拟资源分配和 TOSCA (Top Of Stack Caching)。

不过依然有如下可优化部分：

1. 空闲资源回收机制优化，目前是按照随机顺序分配的（实际是 unordered_set 第一个元素）
2. 评估方法，目前是按照该虚拟资源对应的虚拟寄存器的总引用次数排序，引用次数越多优先获取真实寄存器资源

建议：
 
1. 利好评估方法对空闲资源排序，使用方法让评分最高的虚拟资源能够获得尽可能高的分数，这样获取真实寄存器资源的时候意味着可以在更多地方使用寄存器运算。
2. 前端给予足够多暗示，促进后端对寄存器的评分

> 注意，为了简化部分运算，实际上将 t0，t1，t2，fs0，fs1，fs2 这六个寄存器当作特殊用途寄存器，将它们纳入分配考虑的时候，需要将所有有关它们被特殊用途的地方均修改。

## Live Out 运算办法

使用的是 EaC 上给出的迭代计算方法。性能消耗相当庞大，容易造成编译超时，可以考虑优化。

## Live In 计算

消耗不算大，但是也是可以优化的部分。目前的 Live In 计算逻辑如下：

1. 查询表，获得所有跳转到本基本块的跳转语句
2. 通过跳转语句获取到跳转语句所属的基本块 father（注意，有一个优化，合并 `b` 和 `icmp` 会产生跳转语句，这里需要正确生成 father）
3. 所有相应基本块 father 的 Live Out 的并集就是当前块的 Live In。