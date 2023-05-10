dir="$(pwd)"

export -n RUNFILES_DIR
export -n RUNFILES_MANIFEST_FILE

# would be nice to hide "Generated Terraform code" output
exec "$1" synth -o "$dir"/"$2" >&2
