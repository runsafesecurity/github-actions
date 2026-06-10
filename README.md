# Runsafe Platform Actions

The [RunSafe Platform](https://app.runsafesecurity.com/) can integrate with your GitHub workflows to generate SBOMs, detect vulnerabilities, block builds with incompatible licenses, and more.

To [integrate with C++ builds](#c-github-actions), you must configure your RunSafe license key as a GitHub secret and add RunSafe's GitHub `setup` and `cleanup` actions to your workflows, around your C++ builds.

To [integrate with .NET builds](#net-github-actions), you must configure your RunSafe license key as a GitHub secret and add RunSafe's GitHub `dotnet-setup` and `dotnet-cleanup` actions to your workflows, around your .NET builds.

To [integrate with Docker builds](#docker-github-actions), you must configure your RunSafe license key as a GitHub secret and add RunSafe's GitHub `docker-setup` and `docker-cleanup` actions to your workflows, around your Docker builds.

## Secrets

Your RunSafe license key can be found on the RunSafe Platform [here](https://app.runsafesecurity.com/account/license-key). It must be specified as a secret named `RUNSAFE_LICENSE_KEY` either for your entire GitHub organization or each GitHub project which you configure with the RunSafe Platform. GitHub's documentation on configuring secrets can be found [here](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).

## C++ GitHub Actions

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

### Debug

Setting the environment variable `RUNSAFE_LOG_LEVEL` to `debug` in the build job will add additional logging.

#### Diff with Debug

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
+   env:
+     RUNSAFE_LOG_LEVEL: debug
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

## .NET GitHub Actions

RunSafe also has two actions for .NET builds - `dotnet-setup` and `dotnet-cleanup` - which must be present for your .NET builds to integrate with the RunSafe Platform. The `dotnet-setup` action must go **before** your `dotnet` commands and the `dotnet-cleanup` action must go **after** your `dotnet` commands. The `dotnet-setup` action must also be configured to be able to access your `RUNSAFE_LICENSE_KEY` secret.

If you have multiple jobs with .NET builds they must each be configured with these two RunSafe actions.

### Example

#### Without RunSafe

This sample YAML is for a simple example .NET build which only triggers on PRs against the branch `main`:

```yaml
name: .NET Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  dotnet-build:
    name: .NET Build Job
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build .NET
        description: Build hello_world_out with dotnet
        run: |
          dotnet restore dotnet/RunSafe.HelloWorld.sln
          dotnet build dotnet/RunSafe.HelloWorld.sln --configuration Release --no-restore -o ./hello_world_out -v minimal
```

#### With RunSafe

This sample YAML shows the same build with RunSafe integrated:

```yaml
name: .NET Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  dotnet-build:
    name: .NET Build Job
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      # Runsafe .NET Setup Action
      - uses: runsafesecurity/github-actions/dotnet-setup@v1
        with:
          license_key: ${{ secrets.RUNSAFE_LICENSE_KEY }}
      - name: Build .NET
        description: Build hello_world_out with dotnet
        run: |
          dotnet restore dotnet/RunSafe.HelloWorld.sln
          dotnet build dotnet/RunSafe.HelloWorld.sln --configuration Release --no-restore -o ./hello_world_out -v minimal
      # Runsafe .NET Cleanup Action
      - uses: runsafesecurity/github-actions/dotnet-cleanup@v1
```

#### Diff

This highlights just the diff of adding the RunSafe Platform integration:

```diff
name: .NET Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  dotnet-build:
    name: .NET Build Job
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
+      # Runsafe .NET Setup Action
+      - uses: runsafesecurity/github-actions/dotnet-setup@v1
+        with:
+          license_key: ${{ secrets.RUNSAFE_LICENSE_KEY }}
      - name: Build .NET
        description: Build hello_world_out with dotnet
        run: |
          dotnet restore dotnet/RunSafe.HelloWorld.sln
          dotnet build dotnet/RunSafe.HelloWorld.sln --configuration Release --no-restore -o ./hello_world_out -v minimal
+      # Runsafe .NET Cleanup Action
+      - uses: runsafesecurity/github-actions/dotnet-cleanup@v1
```

### Debug

Setting the environment variable `RUNSAFE_SBOM_LOG_LEVEL` to `debug` in the build job will add additional logging.

#### Diff with Debug

```diff
name: .NET Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  dotnet-build:
    name: .NET Build Job
    runs-on: ubuntu-latest
+   env:
+     RUNSAFE_SBOM_LOG_LEVEL: debug
    steps:
      - uses: actions/checkout@v2
+      # Runsafe .NET Setup Action
+      - uses: runsafesecurity/github-actions/dotnet-setup@v1
+        with:
+          license_key: ${{ secrets.RUNSAFE_LICENSE_KEY }}
      - name: Build .NET
        description: Build hello_world_out with dotnet
        run: |
          dotnet restore dotnet/RunSafe.HelloWorld.sln
          dotnet build dotnet/RunSafe.HelloWorld.sln --configuration Release --no-restore -o ./hello_world_out -v minimal
+      # Runsafe .NET Cleanup Action
+      - uses: runsafesecurity/github-actions/dotnet-cleanup@v1
```

## Docker GitHub Actions

RunSafe also has two actions for Docker builds - `docker-setup` and `docker-cleanup` - which must be present for your Docker builds to integrate with the RunSafe Platform. The `docker-setup` action must go **before** your `docker` commands and the `docker-cleanup` action must go **after** your `docker` commands. The `docker-setup` action must also be configured to be able to access your `RUNSAFE_LICENSE_KEY` secret.

If you have multiple jobs with Docker builds they must each be configured with these two RunSafe actions.

> [!NOTE]
> Docker Actions are not currently available for Windows build environments.

### Example

#### Without RunSafe

This sample YAML is for a simple example Docker build which only triggers on PRs against the branch `main`:

```yaml
name: Docker Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  docker-build:
    name: Docker Build Job
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build Docker
        description: Build demo app with docker
        run: |
          docker build -t demo-app ./app
```

#### With RunSafe

This sample YAML shows the same build with RunSafe integrated:

```yaml
name: Docker Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  docker-build:
    name: Docker Build Job
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      # Runsafe Docker Setup Action
      - uses: runsafesecurity/github-actions/docker-setup@v1
        with:
          license_key: ${{ secrets.RUNSAFE_LICENSE_KEY }}
      - name: Build Docker
        description: Build demo app with docker
        run: |
          docker build -t demo-app ./app
      # Runsafe Docker Cleanup Action
      - uses: runsafesecurity/github-actions/docker-cleanup@v1
```

#### Diff

This highlights just the diff of adding the RunSafe Platform integration:

```diff
name: Docker Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  docker-build:
    name: Docker Build Job
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
+      # Runsafe Docker Setup Action
+      - uses: runsafesecurity/github-actions/docker-setup@v1
+        with:
+          license_key: ${{ secrets.RUNSAFE_LICENSE_KEY }}
      - name: Build Docker
        description: Build demo app with docker
        run: |
          docker build -t demo-app ./app
+      # Runsafe Docker Cleanup Action
+      - uses: runsafesecurity/github-actions/docker-cleanup@v1
```

### Debug

Setting the environment variable `RUNSAFE_SBOM_LOG_LEVEL` to `debug` in the build job will add additional logging.

#### Diff with Debug

```diff
name: Docker Build Workflow
on:
  pull_request:
    branches:
      - main

jobs:
  docker-build:
    name: Docker Build Job
    runs-on: ubuntu-latest
+   env:
+     RUNSAFE_SBOM_LOG_LEVEL: debug
    steps:
      - uses: actions/checkout@v2
+      # Runsafe Docker Setup Action
+      - uses: runsafesecurity/github-actions/docker-setup@v1
+        with:
+          license_key: ${{ secrets.RUNSAFE_LICENSE_KEY }}
      - name: Build Docker
        description: Build demo app with docker
        run: |
          docker build -t demo-app ./app
+      # Runsafe Docker Cleanup Action
+      - uses: runsafesecurity/github-actions/docker-cleanup@v1
```
