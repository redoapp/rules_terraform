cdktf="$1"

output="$2"
[[ "$output" == /* ]] || output="$(pwd)"/"$output"

export -n RUNFILES_DIR

# would be nice to hide "Generated Terraform code" output
exec "$cdktf" synth -o "$output" >&2
