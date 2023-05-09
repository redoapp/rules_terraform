load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:shell.bzl", "shell")
load("@rules_file//generate:providers.bzl", "FormatterInfo")
load("@rules_file//util:path.bzl", "runfile_path")
load(":providers.bzl", "TerraformInfo", "TerraformProviderInfo")

def _cdktf_bin_impl(ctx):
    actions = ctx.actions
    bin = ctx.executable.bin
    bin_default = ctx.attr.bin[DefaultInfo]
    cdktf = ctx.executable.cdktf
    cdktf_default = ctx.attr.cdktf[DefaultInfo]
    config = ctx.file.config
    label = ctx.label
    name = ctx.attr.name
    path = ctx.attr.path
    runner = ctx.file._runner
    terraform = ctx.attr.terraform[TerraformInfo]
    workspace = ctx.workspace_name

    if not path.startswith("/"):
        path = "/".join([part for part in [workspace, label.package, path] if part])

    executable = actions.declare_file(name)
    actions.expand_template(
        is_executable = True,
        output = executable,
        substitutions = {
            "%{cdktf}": shell.quote(runfile_path(workspace, cdktf)),
            "%{bin}": shell.quote(runfile_path(workspace, bin)),
            "%{path}": shell.quote(path),
        },
        template = runner,
    )

    root_symlinks = {
        "%s/%s" % (path, "cdktf.json"): config,
        "_path/terraform": terraform.bin,
    }
    runfiles = ctx.runfiles(root_symlinks = root_symlinks)
    runfiles = runfiles.merge(bin_default.default_runfiles)
    runfiles = runfiles.merge(cdktf_default.default_runfiles)
    default_info = DefaultInfo(
        executable = executable,
        runfiles = runfiles,
    )

    return [default_info]

cdktf_bin = rule(
    attrs = {
        "bin": attr.label(
            doc = "Executable",
            cfg = "target",
            executable = True,
            mandatory = True,
        ),
        "cdktf": attr.label(
            doc = "CDKTF CLI",
            cfg = "target",
            default = ":cdktf",
            executable = True,
        ),
        "config": attr.label(
            allow_single_file = [".json"],
            mandatory = True,
        ),
        "path": attr.string(),
        "terraform": attr.label(
            default = ":terraform",
            providers = [TerraformInfo],
        ),
        "_runner": attr.label(
            allow_single_file = True,
            default = "cdktf-project-runner.sh.tpl",
        ),
    },
    implementation = _cdktf_bin_impl,
)

def _cdktf_synth_impl(ctx):
    actions = ctx.actions
    cdktf_bin = ctx.executable.cdktf_bin
    cdktf_bin_default = ctx.attr.cdktf_bin[DefaultInfo]
    cdktf_synth = ctx.executable._cdktf_synth
    cdktf_synth_default = ctx.attr._cdktf_synth[DefaultInfo]
    name = ctx.attr.name

    out = actions.declare_directory(name)
    actions.run(
        arguments = [cdktf_bin.path, out.path],
        executable = cdktf_synth,
        mnemonic = "CdktfSynth",
        progress_message = "Synthesizing %{output}",
        outputs = [out],
        tools = [cdktf_bin_default.files_to_run, cdktf_synth_default.files_to_run],
    )

    default_info = DefaultInfo(files = depset([out]))

    return [default_info]

cdktf_synth = rule(
    attrs = {
        "cdktf_bin": attr.label(
            cfg = "exec",
            executable = True,
            mandatory = True,
        ),
        "_cdktf_synth": attr.label(
            cfg = "exec",
            executable = True,
            default = ":cdktf_synth",
        ),
    },
    implementation = _cdktf_synth_impl,
)

def cdktf_project(name, bin, config, cdktf = None, terraform = None, visibility = None):
    cdktf_bin(
        name = name,
        bin = bin,
        cdktf = cdktf,
        config = config,
        terraform = terraform,
        visibility = visibility,
    )

    cdktf_synth(
        name = "%s.synth" % name,
        cdktf_bin = name,
        visibility = visibility,
    )

def _tf_bin_impl(ctx):
    actions = ctx.actions
    name = ctx.attr.name
    terraform = ctx.attr.terraform[TerraformInfo]
    runner = ctx.file._runner
    workspace = ctx.workspace_name

    executable = actions.declare_file(name)
    actions.expand_template(
        is_executable = True,
        output = executable,
        substitutions = {
            "%{exec}": shell.quote(runfile_path(workspace, terraform.bin)),
        },
        template = runner,
    )

    runfiles = ctx.runfiles(files = [terraform.bin])
    default_info = DefaultInfo(executable = executable, runfiles = runfiles)

    return [default_info]

tf_bin = rule(
    attrs = {
        "terraform": attr.label(default = ":terraform", providers = [TerraformInfo]),
        "_runner": attr.label(allow_single_file = True, default = "//util:exec-runner.sh.tpl"),
    },
    executable = True,
    implementation = _tf_bin_impl,
)

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

def _tf_format(ctx, src, out, bin):
    ctx.actions.run_shell(
        command = '< "$2" "$1" fmt - > "$3"',
        arguments = [bin.path, src.path, out.path],
        inputs = [bin, src],
        outputs = [out],
    )

def _tf_format_impl(ctx):
    terraform = ctx.attr.terraform[TerraformInfo]

    def format(ctx, path, src, out):
        _tf_format(ctx, src, out, terraform.bin)

    format_info = FormatterInfo(fn = format)

    return [format_info]

tf_format = rule(
    implementation = _tf_format_impl,
    attrs = {
        "terraform": attr.label(
            default = ":terraform",
            providers = [TerraformInfo],
        ),
    },
)

def _tf_project_impl(ctx):
    actions = ctx.actions
    data = ctx.files.data
    data_default = [target[DefaultInfo] for target in ctx.attr.data]
    data_dir = ctx.attr.data_dir or "%s/.terraform" % ctx.attr.name
    label = ctx.label
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

    lock = actions.declare_file("%s.terraform.lock.hcl" % name)

    lock_src = actions.declare_file("%s.lock/main.tf" % name)
    lock_src_content = ""
    lock_src_content += "terraform {\n"
    lock_src_content += "required_providers {\n"
    for i, provider in enumerate(providers):
        lock_src_content += "provider%s = { source = %s, version = %s }\n" % (
            i,
            json.encode("%s/%s/%s" % (provider.hostname, provider.namespace, provider.type)),
            json.encode(provider.version),
        )
    lock_src_content += "}\n"
    lock_src_content += "}\n"
    actions.write(
        output = lock_src,
        content = lock_src_content,
    )

    symlinks = []
    for provider in providers:
        symlink = actions.declare_directory("%s.lock/plugins/%s/%s/%s/%s/%s_%s" % (name, provider.hostname, provider.namespace, provider.type, provider.version, platform.os, platform.arch))
        symlinks.append(symlink)
        actions.symlink(
            output = symlink,
            target_file = provider.file,
        )
    args = actions.args()
    args.add("%s/%s.lock" % (paths.dirname(dummy.path), name))
    args.add(terraform_exec.bin)
    args.add(lock)
    args.add("%s_%s" % (platform.os, platform.arch))
    actions.run_shell(
        arguments = [args],
        command = """
            set -x
            dir="$(pwd)"
            (cd "$1" && "$dir"/"$2" providers lock -fs-mirror=plugins -platform="$4")
            mv "$1"/.terraform.lock.hcl "$3"
        """,
        inputs = [lock_src, terraform_exec.bin] + symlinks,
        outputs = [lock],
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

    root_symlinks = {"%s/%s" % (path, ".terraform.lock.hcl"): lock}
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
        "_runner": attr.label(
            allow_single_file = True,
            default = ":terraform-project-runner.sh.tpl",
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

def _tf_import_cdktf_data_impl(ctx):
    actions = ctx.actions
    cdktf_terraform_data = ctx.executable._cdktf_terraform_data
    cdktf_terraform_data_default = ctx.attr._cdktf_terraform_data[DefaultInfo]
    name = ctx.attr.name
    out = ctx.outputs.output
    stack = ctx.attr.stack
    synth = ctx.file.synth
    workspace = ctx.workspace_name

    actions.run(
        arguments = [synth.path, out.path, stack],
        executable = cdktf_terraform_data,
        inputs = [synth],
        outputs = [out],
        tools = [cdktf_terraform_data_default.files_to_run],
    )

    default_info = DefaultInfo(files = depset([out]))

    return [default_info]

tf_import_cdktf_data = rule(
    attrs = {
        "output": attr.output(mandatory = True),
        "stack": attr.string(
            mandatory = True,
        ),
        "synth": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "_cdktf_terraform_data": attr.label(
            cfg = "exec",
            default = ":cdktf_terraform_data",
            executable = True,
        ),
    },
    implementation = _tf_import_cdktf_data_impl,
)

def tf_import_cdktf(name, stack, synth, data = [], data_dir = None, providers = None, terraform = None, visibility = None):
    tf_import_cdktf_data(
        name = "%s.cdktf" % name,
        output = "%s.tf/cdk.tf.json" % name,
        stack = stack,
        synth = synth,
        visibility = ["//visibility:private"],
    )

    tf_project(
        name = name,
        data = [":%s.cdktf" % name] + data,
        data_dir = data_dir,
        path = "%s.tf" % name,
        providers = providers,
        terraform = terraform,
        visibility = visibility,
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
