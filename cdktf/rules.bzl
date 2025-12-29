load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_util//util:path.bzl", "runfile_path")
load("//terraform:provider.bzl", "TerraformProviderInfo")
load("//terraform:terraform.bzl", "TerraformInfo")
load("//terraform:rules.bzl", "tf_project")

def _cdktf_bin_impl(ctx):
    actions = ctx.actions
    bin = ctx.executable.bin
    bin_default = ctx.attr.bin[DefaultInfo]
    cdktf = ctx.executable.cdktf
    cdktf_default = ctx.attr.cdktf[DefaultInfo]
    config = ctx.file.config
    fake_node = ctx.executable._fake_node
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
        "_path/node": fake_node,
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
        "_fake_node": attr.label(
            cfg = "target",
            default = ":fake_node",
            executable = True,
        ),
        "_runner": attr.label(
            allow_single_file = True,
            default = "project-runner.sh.tpl",
        ),
    },
    implementation = _cdktf_bin_impl,
)

def _cdktf_bindings_impl(ctx):
    actions = ctx.actions
    gen = ctx.executable._gen
    gen_default = ctx.attr._gen[DefaultInfo]
    language = ctx.attr.language
    lock = ctx.executable._lock
    lock_default = ctx.attr._lock[DefaultInfo]
    terraform = ctx.attr.terraform[TerraformInfo]
    tf_config = ctx.file._tf_config
    tf_template = ctx.file._tf_template
    platform = ctx.toolchains["//terraform:platform_toolchain"]
    provider = ctx.attr.provider[TerraformProviderInfo]
    name = ctx.attr.name

    dummy = actions.declare_file("%s.dummy" % name.replace("/", "_"))
    actions.write(dummy, content = "")

    tf = actions.declare_file("%s.tf/main.tf.json" % name)
    actions.expand_template(
        output = tf,
        substitutions = {
            "%{name}": json.encode(provider.type),
            "%{source}": json.encode("%s/%s" % (provider.namespace, provider.type)),
        },
        template = tf_template,
    )

    provider_file = actions.declare_directory("%s.tf/.terraform/providers/%s/%s/%s/%s/%s_%s" % (name, provider.hostname, provider.namespace, provider.type, provider.version, platform.os, platform.arch))
    actions.symlink(
        output = provider_file,
        target_file = provider.file,
    )

    lockfile = actions.declare_file("%s.tf/.terraform.lock.hcl" % name)
    args = actions.args()
    args.add("--platform", "%s_%s" % (platform.os, platform.arch))
    args.add("--providers", "%s/%s.tf/.terraform/providers" % (paths.dirname(dummy.path), name))
    args.add("--terraform", terraform.bin)
    args.add(lockfile)
    actions.run(
        arguments = [args],
        executable = lock,
        mnemonic = "TfProvidersLock",
        inputs = [terraform.bin, provider_file],
        outputs = [lockfile],
        progress_message = "Creating providers lockfile %{label}",
        tools = [lock_default.files_to_run],
    )

    schema = actions.declare_file("%s.schema.json" % name)
    args = actions.args()
    args = actions.args()
    args.add(terraform.bin)
    args.add("%s/%s.tf" % (paths.dirname(dummy.path), name))
    args.add(schema)
    actions.run_shell(
        arguments = [args],
        env = {
            "TF_CLI_CONFIG_FILE": tf_config.path,
        },
        command = '"$1" -chdir="$2" providers schema -json > "$3"',
        inputs = [lockfile, provider_file, terraform.bin, tf, tf_config],
        outputs = [schema],
    )

    args = actions.args()
    out = actions.declare_directory(name)
    args = actions.args()
    args.add("provider")
    args.add("--source", "%s/%s" % (provider.namespace, provider.type))
    args.add(schema)
    args.add(out.path)
    actions.run(
        arguments = [args],
        env = {
            "TERRAFORM_BINARY_NAME": terraform.bin.path,
        },
        executable = gen,
        inputs = [schema],
        tools = [gen_default.files_to_run, terraform.bin],
        outputs = [out],
    )

    default_info = DefaultInfo(files = depset([out]))

    return [default_info]

cdktf_bindings = rule(
    attrs = {
        "language": attr.string(mandatory = True),
        "provider": attr.label(
            mandatory = True,
            providers = [TerraformProviderInfo],
        ),
        "terraform": attr.label(
            cfg = "exec",
            default = "//terraform",
            providers = [TerraformInfo],
        ),
        "_gen": attr.label(
            cfg = "exec",
            default = "//cdktf/gen:bin",
            executable = True,
        ),
        "_lock": attr.label(
            cfg = "exec",
            default = "//terraform/lock:bin",
            executable = True,
        ),
        "_tf_config": attr.label(
            allow_single_file = True,
            default = "//terraform:config.tfrc",
        ),
        "_tf_template": attr.label(
            allow_single_file = True,
            default = ":provider.tf.json.tpl",
        ),
    },
    implementation = _cdktf_bindings_impl,
    toolchains = ["//terraform:platform_toolchain"],
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

def tf_import_cdktf(name, stack, synth, config = None, config_default = None, data = [], data_dir = None, providers = None, terraform = None, visibility = None, **kwargs):
    cdktf_stack(
        name = "%s.tf/cdk" % name,
        stack = stack,
        synth = synth,
        visibility = ["//visibility:private"],
        **kwargs
    )

    tf_project(
        name = name,
        config = config,
        config_default = config_default,
        data = [":%s.tf/cdk" % name] + data,
        data_dir = data_dir,
        path = "%s.tf" % name,
        providers = providers,
        terraform = terraform,
        visibility = visibility,
        **kwargs
    )
