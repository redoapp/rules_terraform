load("@bazel_skylib//lib:shell.bzl", "shell")
load("@rules_file//util:path.bzl", "runfile_path")
load("//terraform:terraform.bzl", "TerraformInfo")
load("//terraform:rules.bzl", "tf_project")

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
            default = "//terraform",
            providers = [TerraformInfo],
        ),
        "_runner": attr.label(
            allow_single_file = True,
            default = "project-runner.sh.tpl",
        ),
    },
    implementation = _cdktf_bin_impl,
)

def _cdktf_synth_impl(ctx):
    actions = ctx.actions
    cdktf_bin = ctx.executable.cdktf_bin
    cdktf_bin_default = ctx.attr.cdktf_bin[DefaultInfo]
    name = ctx.attr.name
    synth = ctx.executable._synth
    synth_default = ctx.attr._synth[DefaultInfo]

    out = actions.declare_directory(name)
    actions.run(
        arguments = [cdktf_bin.path, out.path],
        executable = synth,
        mnemonic = "CdktfSynth",
        outputs = [out],
        progress_message = "Synthesizing CDKTF %{label}",
        tools = [cdktf_bin_default.files_to_run, synth_default.files_to_run],
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
        "_synth": attr.label(
            cfg = "exec",
            executable = True,
            default = "//cdktf/synth:bin",
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

def _cdktf_stack_impl(ctx):
    actions = ctx.actions
    name = ctx.attr.name
    stack = ctx.attr.stack
    synth = ctx.file.synth

    output = actions.declare_file("%s.tf.json" % name)

    args = actions.args()
    args.add("%s/stacks/%s/cdk.tf.json" % (synth.path, stack))
    args.add(output)
    actions.run(
        arguments = [args],
        executable = "cp",
        inputs = [synth],
        mnemonic = "CdktfStack",
        progress_message = "Extracting CDKTF stack %{label}",
        outputs = [output],
    )

    default_info = DefaultInfo(files = depset([output]))

    return [default_info]

cdktf_stack = rule(
    attrs = {
        "stack": attr.string(
            mandatory = True,
        ),
        "synth": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
    },
    implementation = _cdktf_stack_impl,
)

def tf_import_cdktf(name, stack, synth, data = [], data_dir = None, providers = None, terraform = None, visibility = None, **kwargs):
    cdktf_stack(
        name = "%s.tf/cdk" % name,
        stack = stack,
        synth = synth,
        visibility = ["//visibility:private"],
        **kwargs
    )

    tf_project(
        name = name,
        data = [":%s.tf/cdk" % name] + data,
        data_dir = data_dir,
        path = "%s.tf" % name,
        providers = providers,
        terraform = terraform,
        visibility = visibility,
        **kwargs
    )
