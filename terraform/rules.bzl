load("@bazel_skylib//lib:shell.bzl", "shell")
load("@rules_file//generate:providers.bzl", "FormatterInfo")
load("@rules_file//util:path.bzl", "runfile_path")

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
    terraform = ctx.file._terraform
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

    runfiles = ctx.runfiles(files = [terraform], root_symlinks = {"%s/%s" % (path, "cdktf.json"): config, "_path/terraform": terraform})
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
            cfg = "target",
            executable = True,
            mandatory = True,
        ),
        "cdktf": attr.label(
            cfg = "target",
            executable = True,
            mandatory = True,
        ),
        "config": attr.label(
            allow_single_file = [".json"],
            mandatory = True,
        ),
        "path": attr.string(),
        "_runner": attr.label(
            allow_single_file = True,
            default = "cdktf-project-runner.sh.tpl",
        ),
        "_terraform": attr.label(
            allow_single_file = True,
            default = "@terraform//:terraform",
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

def cdktf_project(name, cdktf, bin, config, visibility = None):
    cdktf_bin(
        name = name,
        bin = bin,
        cdktf = cdktf,
        config = config,
        visibility = visibility,
    )

    cdktf_synth(
        name = "%s.synth" % name,
        cdktf_bin = name,
        visibility = visibility,
    )

def _tf_format(ctx, src, out, bin):
    ctx.actions.run_shell(
        command = '< "$2" "$1" fmt - > "$3"',
        arguments = [bin.path, src.path, out.path],
        inputs = [bin, src],
        outputs = [out],
    )

def _tf_format_impl(ctx):
    terraform = ctx.file._terraform

    def format(ctx, path, src, out):
        _tf_format(ctx, src, out, terraform)

    format_info = FormatterInfo(fn = format)

    return [format_info]

tf_format = rule(
    implementation = _tf_format_impl,
    attrs = {
        "_terraform": attr.label(allow_single_file = True, default = "@terraform//:terraform"),
    },
)

def _tf_project_impl(ctx):
    actions = ctx.actions
    data = ctx.files.data
    data_default = [target[DefaultInfo] for target in ctx.attr.data]
    label = ctx.label
    name = ctx.attr.name
    path = ctx.attr.path
    runner = ctx.file._runner
    terraform = ctx.file._terraform
    workspace = ctx.workspace_name

    if not path.startswith("/"):
        path = "/".join([part for part in [workspace, label.package, path] if part])

    executable = actions.declare_file(name)
    actions.expand_template(
        is_executable = True,
        output = executable,
        substitutions = {
            "%{package}": shell.quote("/".join(path.split("/")[1:])),
            "%{path}": shell.quote(path),
            "%{terraform}": shell.quote(runfile_path(workspace, terraform)),
        },
        template = runner,
    )

    runfiles = ctx.runfiles(files = [terraform] + data)
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
        "path": attr.string(),
        "_runner": attr.label(
            allow_single_file = True,
            default = ":terraform-project-runner.sh.tpl",
        ),
        "_terraform": attr.label(
            allow_single_file = True,
            default = "@terraform//:terraform",
        ),
    },
    executable = True,
    implementation = _tf_project_impl,
)

def _tf_import_cdktf_data_impl(ctx):
    actions = ctx.actions
    cdktf_terraform_data = ctx.executable._cdktf_terraform_data
    cdktf_terraform_data_default = ctx.attr._cdktf_terraform_data[DefaultInfo]
    lock = ctx.file.lock
    name = ctx.attr.name
    stack = ctx.attr.stack
    synth = ctx.file.synth
    workspace = ctx.workspace_name

    out = actions.declare_directory(name)
    actions.run(
        arguments = [synth.path, out.path, stack, lock.path],
        executable = cdktf_terraform_data,
        inputs = [lock, synth],
        outputs = [out],
        tools = [cdktf_terraform_data_default.files_to_run],
    )

    default_info = DefaultInfo(files = depset([out]))

    return [default_info]

tf_import_cdktf_data = rule(
    attrs = {
        "lock": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
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

def tf_import_cdktf(name, lock, stack, synth, visibility = None):
    tf_import_cdktf_data(
        name = ".cdktf/%s" % name,
        lock = lock,
        stack = stack,
        synth = synth,
        visibility = ["//visibility:private"],
    )

    tf_project(
        name = name,
        data = [":.cdktf/%s" % name],
        path = ".cdktf/%s" % name,
        visibility = visibility,
    )

def _tf_lock_impl(ctx):
    actions = ctx.actions
    output = ctx.attr.output or "%s%s" % ("%s/" % ctx.label.package if ctx.label.package else "", ".terraform.lock.hcl")
    label = ctx.label
    name = ctx.attr.name
    path = ctx.attr.path
    runner = ctx.file._runner
    terraform = ctx.executable.terraform
    terraform_default = ctx.attr.terraform[DefaultInfo]
    workspace = ctx.workspace_name

    if not output.startswith("/"):
        output = "/".join([part for part in [label.package, output] if part])

    if not path.startswith("/"):
        path = "/".join([part for part in [workspace, label.package, path] if part])

    executable = actions.declare_file(name)
    actions.expand_template(
        is_executable = True,
        output = executable,
        substitutions = {
            "%{output}": shell.quote(output),
            "%{path}": shell.quote(path),
            "%{terraform}": shell.quote(runfile_path(workspace, terraform)),
        },
        template = runner,
    )

    runfiles = terraform_default.default_runfiles
    default_info = DefaultInfo(
        executable = executable,
        runfiles = runfiles,
    )

    return [default_info]

tf_lock = rule(
    attrs = {
        "output": attr.string(),
        "path": attr.string(
            mandatory = True,
        ),
        "terraform": attr.label(
            cfg = "target",
            executable = True,
            mandatory = True,
        ),
        "_runner": attr.label(
            allow_single_file = True,
            default = "terraform-lock-runner.sh.tpl",
        ),
    },
    executable = True,
    implementation = _tf_lock_impl,
)
