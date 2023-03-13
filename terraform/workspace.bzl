load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

def tf_repositories():
    http_archive(
        name = "terraform",
        build_file = "@rules_terraform//terraform:terraform.bazel",
        sha256 = "fa5cbf4274c67f2937cabf1a6544529d35d0b8b729ce814b40d0611fd26193c1",
        url = "https://releases.hashicorp.com/terraform/1.3.3/terraform_1.3.3_linux_amd64.zip",
    )
