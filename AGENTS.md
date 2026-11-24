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
