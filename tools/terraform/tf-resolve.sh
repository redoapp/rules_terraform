tmp="$(mktemp)"
"$(rlocation rules_terraform/terraform/resolve-tf/bin)" \
    --version 1.1.9 \
    --version 1.2.9 \
    --version 1.3.9 \
    --version 1.4.6 \
    > "$tmp"
exec mv "$tmp" "$BUILD_WORKING_DIRECTORY"/terraform/default/terraform.bzl
