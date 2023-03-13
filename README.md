# Rules Terraform

Bazel rules for Terraform

## Example

```
load("@rules_terraform//terraform:rules.bzl", "tf_lock", "tf_project")

tf_lock(

)

tf_project(

)
```
