load("//terraform:workspace.bzl", "tf_providers")
load(":providers.bzl", "PROVIDERS")

def tf_test_repositories():
    tf_providers(name = "tf", providers = PROVIDERS)
