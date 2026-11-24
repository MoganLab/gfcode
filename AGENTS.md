# AGENTS.md — gfcode

## Browsing Library Documentation: `gf doc`

`gf doc` browses Goldfish Scheme library documentation by reading test files from
the `tests/` directory. **Always run it before reading a library source file
to guess an API** — the doc output already contains syntax, parameters, return
values, error handling, and runnable test examples.

### Usage

```bash
gf doc ORG/LIB              # library overview + function index
gf doc ORG/LIB "FUNC"       # one function within a library (syntax, examples, tests)
gf doc "FUNC"               # search a function across all libraries (fuzzy match)
gf doc --build-json         # rebuild the global function index (run after test files change)
```

### Examples for this repo

```bash
# A Goldfish standard library
gf doc liii/path
gf doc liii/path "path-read-text"
gf doc liii/string "string-split"
gf doc liii/timeit          # perf measurement helper

# Fuzzy search when you only remember part of the name
gf doc "string-spli"        # suggests "string-split"
```

### Function name → test file mapping

Special characters in function names map to test-file stems:

| Char | Stem    | Example                       |
|------|---------|-------------------------------|
| `?`  | `-p`    | `path?` → `path-p`            |
| `!`  | `-bang` | `reverse!` → `reverse-bang`   |
| `->` | `-to-`  | `list->vector` → `list-to-vector` |
| `/`  | `-slash-` | `path/join` → `path-slash-join` |
| `+`  | `plus`  | `+` → `plus`                  |
| `*`  | `star`  | `*` → `star`                  |
| `=`  | `eq`    | `=` → `eq`                   |
| `<`/`>` | `lt`/`gt` | `char<` → `char-lt`       |

### Notes

- `gf doc` resolves libraries through `*load-path*`; standard Goldfish libraries
  (e.g. `liii/path`, `liii/string`, `liii/list`, `liii/timeit`) are always
  available. The local gfcode libraries live under `org/liii/pi/...`
  (see the `agent/`, `ai/`, `code/`, `tui/`, etc. trees).
- If a function index lookup fails ("function index not found"), run
  `gf doc --build-json` once to (re)build the index.
- Documentation is derived from `tests/` — keep tests self-documenting
  (syntax/params/return/error comments at the top of each test file) so
  `gf doc` output stays useful.

## Running Tests: `gf test`

`gf test` runs all `*-test.scm` files under `tests/`. Use it to verify
changes and reproduce failures.

### Usage

```bash
gf test                              # run all tests
gf test tests/liii/string/          # run tests in a directory
gf test string-test.scm             # run a specific test file
gf test string                      # run tests whose path contains "string"
gf test --changed-since=HEAD        # run only changed *-test.scm files
gf test -V tests/liii/json/         # show full output for failed tests
```

### Notes

- Test files must end with `-test.scm`.
- Paths containing `/tests/` auto-switch to the parent directory before running
  (e.g. `gf test tools/doc/tests/` runs as if from `tools/doc/`).
- `--changed-since=<rev>` uses `git diff --name-only`; it does not include changed
  dependents.
- By default, failed tests show the last 20 lines of output plus a rerun hint;
  pass `-V` / `--verbose` to see the full output.
- Returns exit code 0 if all tests pass, non-zero otherwise.

## Formatting Code: `gf fmt`

`gf fmt` formats Scheme (`.scm`/`.sld`) and C++/stem sources. Run it before
committing so the tree stays consistent with the repo style.

### Usage

```bash
gf fmt                       # format the whole repo per gf_fmt.json (C++ + Scheme)
gf fmt file.scm              # format a single file
gf fmt /path/to/dir          # recursively format .scm under a directory
gf fmt -e scm,sld dir/       # format .scm and .sld files
gf fmt --dry-run file.scm    # preview formatting without writing back
gf fmt --check               # CI non-destructive check; exit 1 if unformatted
gf fmt --check /path/to/dir  # CI check for a specific directory
gf fmt --changed-since=HEAD  # format files changed since HEAD
```

### Notes

- With no path, reads `gf_fmt.json` and formats all languages (scheme + cpp + stem).
- `--check` is non-destructive: exits 1 if any file is not formatted (use in CI).
- `--dry-run` prints the formatted result; not supported for directory paths.
- `--changed-since=<rev>` formats files changed since a git revision (filtered by `-e`).
- `-e` / `--extension` selects a language by name (`scheme`, `cpp`, `stem`) or
  file suffix (e.g. `scm,sld`); `-e cpp` covers `.cpp/.hpp/.h/.c/.cc/.cxx`.
- `--exclude PATTERN` skips matching files (comma-separated, path-suffix match).
- `-j` / `--jobs NUM` sets formatting concurrency (0 = auto, 1 = single worker).
