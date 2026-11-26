# (liii pi code modes verbose thinking) 模块函数分类索引

`(liii pi code modes verbose thinking)` 提供 verbose 模式思考（reasoning）阶段的状态跟踪与展示，包括开始、按间隔提示仍在思考、结束及耗时格式化；思考内容本身从不打印。

使用时导入：

```scheme
(import (liii pi code modes verbose thinking))
```

## 查看函数文档

```bash
gf doc verbose-thinking-ping-due?
```

## 函数分类索引

### 思考状态展示
- `verbose-thinking-ping-due?` - 判断是否到达思考进度提示阈值
