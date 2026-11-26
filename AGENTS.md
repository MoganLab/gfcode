# AGENTS.md

## Library documentation

Run `gf doc` before reading library source code to infer an API.

```bash
gf doc ORG/LIB              # library overview and function index
gf doc ORG/LIB "FUNC"       # documentation and examples for one function
gf doc "FUNC"               # fuzzy search across libraries
gf doc --build-json         # rebuild the index after test files change
```

Documentation comes from `tests/`. Keep syntax, parameters, return values, and
error behavior documented at the top of each test file.

`gf check` 的 `unit-test` 规则按报错提示修复，**不要去看 `gf check` 的实现**：

- 测试文件顶部文档只认可 `语法`、`参数`、`返回值` 三个小节标题（后跟 `;; ----`
  下划线行）；出现 `错误行为` 等其他小节标题会报 `未知的小节标题【...】`，
  把错误行为说明并入 `返回值` 描述或写成普通 `;;` 正文（不带下划线分隔）。
- `max-tree-depth` 超限（默认 <= 15）时按报错提示的文件/行号降低该处嵌套层数
  （提取 let* 中间量、拆辅助函数等），不要改宽全局阈值。
- 其他规则（如 `缺少导出函数 ... 的单元测试`）按提示补对应测试文件或修正归
  属，不要修改 `gf check` 本身。

## Tests

```bash
gf test                       # all tests
gf test tests/liii/string/    # tests in a directory
gf test string-test.scm       # one test file
gf test string                # tests whose path contains "string"
gf test --changed-since=HEAD  # changed test files only
gf test -V tests/liii/json/   # full output for failures
```

Test files must end with `-test.scm`.

## Formatting

Run `gf fmt` before committing.

```bash
gf fmt                        # format the repository
gf fmt file.scm               # format one file
gf fmt path/to/dir            # format a directory recursively
gf fmt --changed-since=HEAD   # format files changed since HEAD
gf fmt --check                # check without modifying files
```

Scheme (`.scm`/`.sld`), C++, and stem sources are supported.
