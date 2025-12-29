load("@bazel_util//file:workspace.bzl", "files")

def file_repositories():
    files(
        name = "files",
        build = "//tools/file:files.bazel",
        ignores = [".git", "node_modules"],
        root_file = "//:WORKSPACE.bazel",
    )
