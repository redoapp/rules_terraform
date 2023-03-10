load("@bazel_skylib//lib:shell.bzl", "shell")
load("@rules_file//util:path.bzl", "runfile_path")

def _sh_binary_impl(ctx):
    actions = ctx.actions
    main = ctx.file.main
    name = ctx.attr.name
    runner = ctx.file._runner
    workspace_name = ctx.workspace_name
    deps = [target[DefaultInfo] for target in ctx.attr.deps]
    data = [target[DefaultInfo] for target in ctx.attr.data]

    executable = actions.declare_file(name)
    actions.expand_template(
        template = runner,
        output = executable,
        is_executable = True,
        substitutions = {
            "%{main}": shell.quote(runfile_path(workspace_name, main)),
        },
    )

    runfiles = ctx.runfiles(files = [main], transitive_files = depset(transitive = [default_info.files for default_info in data]))
    runfiles = runfiles.merge_all([default_info.default_runfiles for default_info in deps])
    runfiles = runfiles.merge_all([default_info.data_runfiles for default_info in data])

    default_info = DefaultInfo(
        executable = executable,
        runfiles = runfiles,
    )

    return [default_info]

sh_binary = rule(
    attrs = {
        "main": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "data": attr.label_list(
            allow_files = True,
        ),
        "deps": attr.label_list(
        ),
        "_runner": attr.label(
            allow_single_file = True,
            default = ":runner",
        ),
    },
    implementation = _sh_binary_impl,
    executable = True,
)
