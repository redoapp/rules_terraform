load("//util:collection.bzl", "unique")

TERRAFORM_REPOS = {
    "1.4.2": {
        "darwin_amd64": struct(
            sha256 = "c218a6c0ef6692b25af16995c8c7bdf6739e9638fef9235c6aced3cd84afaf66",
        ),
        "darwin_arm64": struct(
            sha256 = "af8ff7576c8fc41496fdf97e9199b00d8d81729a6a0e821eaf4dfd08aa763540",
        ),
        "linux_amd64": struct(
            sha256 = "9f3ca33d04f5335472829d1df7785115b60176d610ae6f1583343b0a2221a931",
        ),
        "linux_arm64": struct(
            sha256 = "39c182670c4e63e918e0a16080b1cc47bb16e158d7da96333d682d6a9cb8eb91",
        ),
        "windows_amd64": struct(
            sha256 = "7edfbad5c22e8c62e403c26ee1d10f71cebcc87def267b17fd5c9e9ed90312aa",
        ),
    },
}

TERRAFORM_PLATFORMS = unique([name for repos in TERRAFORM_REPOS.values() for name in repos.keys()])
