load("//terraform:workspace.bzl", "tf_repositories", "tf_toolchains")
load("//tools/npm:workspace.bzl", "npm_repositories")

def repositories():
    npm_repositories()
    tf_repositories()

def toolchains():
    tf_toolchains()
