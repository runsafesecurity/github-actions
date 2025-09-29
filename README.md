# Runsafe Platform Actions

The [RunSafe Platform](https://app.runsafesecurity.com/) can integrate with your GitHub workflows to generate SBOMs, detect vulnerabilities, block builds with incompatible licenses, and more.

To integrate with C++ builds, you must configure your RunSafe license key as a GitHub secret and add RunSafe's GitHub `setup` and `cleanup` actions to your workflows, around your C++ builds.

## Secrets

Your RunSafe license key can be found on the RunSafe Platform [here](https://app.runsafesecurity.com/account/license-key). It must be specified as a secret named `RUNSAFE_LICENSE_KEY` either in your organization or each project which you configure with the RunSafe Platform. GitHub's documentation on configuring secrets can be found [here](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).

## GitHub Actions

RunSafe has two actions - `setup` and `cleanup` - which must be present for your C++ builds to integrate with the RunSafe Platform. The `setup` action must go **before** your C++ build and the `cleanup` action must go **after** your C++ build. The `setup` action must also be configured to be able to access your `RUNSAFE_LICENSE_KEY` secret.

If you have multiple jobs with C++ builds they must each be configured with these two RunSafe actions.

### Example

#### Without RunSafe

This sample YAML is for a simple example C++ build of Hello World which only triggers on PRs against the branch `main`:

```yaml
name: C++ Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  cpp-build:
    name: C++ Build Job
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build cpp
        description: Build hello_world with make
        run: make hello_world
```

#### With RunSafe

This sample YAML shows the same build with RunSafe integrated:

```yaml
name: C++ Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  cpp-build:
    name: C++ Build Job
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      # Runsafe Setup Action
      - uses: runsafesecurity/github-actions/setup@v1
        with:
          license_key: ${{ secrets.RUNSAFE_LICENSE_KEY }}
      - name: Build cpp
        description: Build hello_world with make
        run: make hello_world
      # Runsafe Cleanup Action
      - uses: runsafesecurity/github-actions/cleanup@v1
```

#### Diff

This highlights just the diff of adding the RunSafe Platform integration:

```diff
name: C++ Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  cpp-build:
    name: C++ Build Job
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
+      # Runsafe Setup Action
+      - uses: runsafesecurity/github-actions/setup@v1
+        with:
+          license_key: ${{ secrets.RUNSAFE_LICENSE_KEY }}
      - name: Build cpp
        description: Build hello_world with make
        run: make hello_world
+      # Runsafe Cleanup Action
+      - uses: runsafesecurity/github-actions/cleanup@v1
```
