TerraformProviderInfo = provider(
    fields = {
        "file": "File",
        "hostname": "Canonical hostname",
        "namespace": "Namespace",
        "type": "Provider name",
        "version": "Version",
    },
)

def _provider_src_impl(ctx, toolchain):
    provider = ctx.toolchains[toolchain]

    default_info = DefaultInfo(files = depset([provider.file]))

    return [default_info]

def provider_src_rule(toolchain):
    def impl(ctx):
        return _provider_src_impl(ctx, toolchain)

    return rule(
        toolchains = [toolchain],
        implementation = impl,
    )

def provider_toolchain_name(os, cpu):
    return "toolchain_%s_%s" % (os, cpu)
