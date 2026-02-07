load("%{provider}", "provider_bin_rule")

provider_bin = provider_bin_rule(
    toolchain = Label(":provider_type"),
)
