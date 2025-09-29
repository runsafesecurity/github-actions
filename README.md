# Runsafe Platform Action

## Usage:

```yaml
name: C++ Build with Runsafe Platform
on:
  pull_request:
    branches:
      - main

jobs:
  cpp-build:
    name: C++ Build with Runsafe Platform
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      # Runsafe Setup Action
      - uses: runsafesecurity/github-actions/setup@v1
        with:
          license_key: ${{ secrets.RUNSAFE_LICENSE_KEY }}
      - name: Build cpp
        description: Replace below with your C++ build
        run: ldd ./util/hello
      # Runsafe Cleanup Action
      - uses: runsafesecurity/github-actions/cleanup@v1
```
