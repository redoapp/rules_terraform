# Rules Terraform

Bazel rules for Terraform

## Install

```
RULES_TERRAFORM_VERSION = "..."

http_archive(
    name = "rules_terraform",
    # sha256 = "...",
    strip_prefix = "rules_terraform-%s" % RULES_TERRAFORM_VERSION,
    url = "https://github.com/redoapp/rules_terraform/archive/%s.zip" % RULES_TERRAFORM_VERSION,
)

load("@rules_terraform//:workspace.bzl", rules_terraform_deps = "deps")

rules_terraform_deps()
```

## Terraform Example

**BUILD.bazel**

```bzl
load("@rules_terraform//terraform:rules.bzl", "tf_project")

tf_project(
    name = "tf",
    data = glob(["*.tf"]),
)
```

```sh
bazel run :tf -- init
bazel run :tf -- apply
```

## CDKTF Example

**BUILD.bazel**

```bzl
load("@rules_terraform//cdktf:rules.bzl", "cdktf_project", "tf_import_cdktf")

cdktf_project(
    name = "cdktf",
    bin = ":bin",
    config = "cdktf.json",
)

tf_import_cdktf(
    name = "tf",
    stack = "Main",
    synth = ":cdktf.synth",
)
```

```sh
bazel run :tf -- init
bazel run :tf -- apply
```
