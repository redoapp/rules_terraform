load("//terraform:workspace.bzl", "tf_platforms", "tf_toolchains")
load("//tools/npm:workspace.bzl", "npm_repositories")

def deps(terraform_version = "1.6.6"):
    npm_repositories()
    tf_platforms()
    tf_toolchains(version = terraform_version)
