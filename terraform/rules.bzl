load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:shell.bzl", "shell")
load("@rules_file//generate:providers.bzl", "FormatterInfo")
load("@rules_file//util:path.bzl", "runfile_path")
load(":terraform.bzl", "TerraformInfo")
load(":provider.bzl", "TerraformProviderInfo")

def _tf_platform_toolchain_impl(ctx):
    arch = ctx.attr.arch
    os = ctx.attr.os

    toolchain_info = platform_common.ToolchainInfo(
        arch = arch,
        os = os,
    )

    return [toolchain_info]

tf_platform_toolchain = rule(
    attrs = {
        "arch": attr.string(mandatory = True),
        "os": attr.string(mandatory = True),
    },
    implementation = _tf_platform_toolchain_impl,
    provides = [platform_common.ToolchainInfo],
)

def _tf_provider_impl(ctx):
    actions = ctx.actions
    hostname = ctx.attr.hostname
    name = ctx.attr.name
    namespace = ctx.attr.namespace
    src = ctx.file.src
    type = ctx.attr.type
    version = ctx.attr.version

    tf_provider_info = TerraformProviderInfo(
        hostname = hostname,
        file = src,
        namespace = namespace,
        type = type,
        version = version,
    )

    default_info = DefaultInfo(files = depset([src]))

    return [default_info, tf_provider_info]

tf_provider = rule(
    attrs = {
        "hostname": attr.string(default = "registry.terraform.io"),
        "namespace": attr.string(default = "hashicorp"),
        "type": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
        "src": attr.label(allow_single_file = True),
    },
    implementation = _tf_provider_impl,
    provides = [TerraformProviderInfo],
)

def _tf_provider_toolchain_impl(ctx):
    src = ctx.file.src

    toolchain_info = platform_common.ToolchainInfo(
        file = src,
    )

    return [toolchain_info]

tf_provider_toolchain = rule(
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
    },
    implementation = _tf_provider_toolchain_impl,
    provides = [platform_common.ToolchainInfo],
)

def _tf_providers_resolve_impl(ctx):
    actions = ctx.actions
    bash_runfiles_default = ctx.attr._bash_runfiles[DefaultInfo]
    name = ctx.attr.name
    path = ctx.attr.path
    providers = ctx.attr.providers
    label = ctx.label
    resolve = ctx.executable._resolve
    resolve_default = ctx.attr._resolve[DefaultInfo]
    runner = ctx.file._runner
    workspace = ctx.workspace_name

    if not path.startswith("/") and label.package:
        path = "%s/%s" % (label.package, path)

    executable = actions.declare_file(name)
    actions.expand_template(
        is_executable = True,
        output = executable,
        substitutions = {
            "%{path}": shell.quote(path),
            "%{providers}": " ".join([
                shell.quote("%s=%s" % (name, provider))
                for name, provider in providers.items()
            ]),
            "%{resolve}": shell.quote(runfile_path(workspace, resolve)),
        },
        template = runner,
    )

    runfiles = bash_runfiles_default.default_runfiles
    runfiles = runfiles.merge(resolve_default.default_runfiles)
    default_info = DefaultInfo(executable = executable, runfiles = runfiles)

    return [default_info]

tf_providers_resolve = rule(
    attrs = {
        "path": attr.string(mandatory = True),
        "providers": attr.string_dict(),
        "_bash_runfiles": attr.label(default = "@bazel_tools//tools/bash/runfiles"),
        "_resolve": attr.label(cfg = "target", default = "//terraform/resolve:bin", executable = True),
        "_runner": attr.label(allow_single_file = True, default = "providers-resolve.sh.tpl"),
    },
    executable = True,
    implementation = _tf_providers_resolve_impl,
)

def _tf_toolchain(ctx):
    bin = ctx.file.bin

    toolchain_info = platform_common.ToolchainInfo(
        bin = bin,
    )

    return [toolchain_info]

tf_toolchain = rule(
    attrs = {
        "bin": attr.label(allow_single_file = True, mandatory = True),
    },
    implementation = _tf_toolchain,
    provides = [platform_common.ToolchainInfo],
)

def _tf_format(ctx, src, out, format, format_default, bin):
    args = ctx.actions.args()
    args.add(bin)
    args.add(src)
    args.add(out)
    ctx.actions.run(
        arguments = [args],
        executable = format,
        mnemonic = "TfFormat",
        progress_message = "Formatting %{input}",
        inputs = [src, bin],
        tools = [format_default.files_to_run],
        outputs = [out],
    )

def _tf_format_impl(ctx):
    terraform = ctx.attr.terraform[TerraformInfo]
    format = ctx.executable._format
    format_default = ctx.attr._format[DefaultInfo]

    def format(ctx, path, src, out):
        _tf_format(ctx, src, out, format, format_default, terraform.bin)

    format_info = FormatterInfo(fn = format)

    return [format_info]

tf_format = rule(
    implementation = _tf_format_impl,
    attrs = {
        "terraform": attr.label(
            default = ":terraform",
            providers = [TerraformInfo],
        ),
        "_format": attr.label(
            cfg = "exec",
            default = "//terraform/format:bin",
            executable = True,
        ),
    },
)

def _tf_project_impl(ctx):
    actions = ctx.actions
    data = ctx.files.data
    data_default = [target[DefaultInfo] for target in ctx.attr.data]
    data_dir = ctx.attr.data_dir or "%s/.terraform" % ctx.attr.name
    label = ctx.label
    lock = ctx.executable._lock
    lock_default = ctx.attr._lock[DefaultInfo]
    name = ctx.attr.name
    path = ctx.attr.path
    platform = ctx.toolchains[":platform_toolchain"]
    providers = [target[TerraformProviderInfo] for target in ctx.attr.providers]
    runner = ctx.file._runner
    terraform = ctx.attr.terraform[TerraformInfo]
    terraform_exec = ctx.attr.terraform[TerraformInfo]
    workspace = ctx.workspace_name

    if not path.startswith("/"):
        path = "/".join([part for part in [workspace, label.package, path] if part])

    if not data_dir.startswith("/"):
        data_dir = "/".join([part for part in [label.package, data_dir] if part])

    dummy = actions.declare_file("%s.dummy" % name)
    actions.write(dummy, content = "")

    lockfile = actions.declare_file("%s.terraform.lock.hcl" % name)

    symlinks = []
    for provider in providers:
        symlink = actions.declare_directory("%s.plugins/%s/%s/%s/%s/%s_%s" % (name, provider.hostname, provider.namespace, provider.type, provider.version, platform.os, platform.arch))
        symlinks.append(symlink)
        actions.symlink(
            output = symlink,
            target_file = provider.file,
        )
    args = actions.args()
    args.add("--platform", "%s_%s" % (platform.os, platform.arch))
    args.add("--providers", "%s/%s.plugins" % (paths.dirname(dummy.path), name))
    args.add("--terraform", terraform_exec.bin)
    args.add(lockfile)
    actions.run(
        arguments = [args],
        executable = lock,
        mnemonic = "TfProvidersLock",
        inputs = [terraform_exec.bin] + symlinks,
        outputs = [lockfile],
        progress_message = "Creating providers lockfile %{label}",
        tools = [lock_default.files_to_run],
    )

    executable = actions.declare_file(name)
    actions.expand_template(
        is_executable = True,
        output = executable,
        substitutions = {
            "%{data_dir}": shell.quote(data_dir),
            "%{package}": shell.quote("/".join(path.split("/")[1:])),
            "%{path}": shell.quote(path),
            "%{terraform}": shell.quote(runfile_path(workspace, terraform.bin)),
        },
        template = runner,
    )

    root_symlinks = {"%s/%s" % (path, ".terraform.lock.hcl"): lockfile}
    for provider in providers:
        provider_path = "%s/%s/%s/%s/%s_%s" % (provider.hostname, provider.namespace, provider.type, provider.version, platform.os, platform.arch)
        root_symlinks["%s/terraform.d/plugins/%s" % (path, provider_path)] = provider.file

    runfiles = ctx.runfiles(files = [terraform.bin] + data, root_symlinks = root_symlinks)
    runfiles = runfiles.merge_all([default_info.default_runfiles for default_info in data_default])
    default_info = DefaultInfo(
        executable = executable,
        runfiles = runfiles,
    )

    return [default_info]

tf_project = rule(
    attrs = {
        "data": attr.label_list(
            allow_files = True,
        ),
        "data_dir": attr.string(),
        "path": attr.string(),
        "providers": attr.label_list(providers = [TerraformProviderInfo]),
        "terraform": attr.label(
            default = ":terraform",
            providers = [TerraformInfo],
        ),
        "_lock": attr.label(
            cfg = "exec",
            default = "//terraform/lock:bin",
            executable = True,
        ),
        "_runner": attr.label(
            allow_single_file = True,
            default = "project-runner.sh.tpl",
        ),
        "_terraform_exec": attr.label(
            cfg = "exec",
            default = ":terraform",
            providers = [TerraformInfo],
        ),
    },
    executable = True,
    implementation = _tf_project_impl,
    toolchains = [":platform_toolchain"],
)

def _tf_toolchain_terraform_impl(ctx):
    toolchain = ctx.toolchains[":toolchain_type"]

    terraform_info = TerraformInfo(
        bin = toolchain.bin,
    )

    return [terraform_info]

tf_toolchain_terraform = rule(
    implementation = _tf_toolchain_terraform_impl,
    toolchains = [":toolchain_type"],
    provides = [TerraformInfo],
)
