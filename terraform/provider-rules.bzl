load("@rules_terraform//terraform:provider.bzl", "provider_src_rule")

provider_src = provider_src_rule(
    toolchain = Label(":toolchain_type"),
)
