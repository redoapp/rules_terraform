dir="$(pwd)"

export -n RUNFILES_DIR
export -n RUNFILES_MANIFEST_FILE

export CDKTF_DISABLE_PLUGIN_CACHE_ENV=true
export CI=true

exec "$1" synth -o "$dir"/"$2"
