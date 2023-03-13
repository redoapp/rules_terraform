# Rules Terraform

Bazel rules for Terraform

## Example

```
load("@rules_terraform//terraform:rules.bzl", "terraform_lock")

terraform_lock(

)

terraform_project(

)
```
