TerraformProviderInfo = provider(
    fields = {
        "file": "File",
        "hostname": "Canonical hostname",
        "namespace": "Namespace",
        "type": "Provider name",
        "version": "Version",
    },
)

def _provider_bin_impl(ctx, toolchain):
    provider = ctx.toolchains[toolchain]

    default_info = DefaultInfo(files = depset([provider.file]))

    return [default_info]

def provider_bin_rule(toolchain):
    def impl(ctx):
        return _provider_bin_impl(ctx, toolchain)

    return rule(
        toolchains = [toolchain],
        implementation = impl,
    )
