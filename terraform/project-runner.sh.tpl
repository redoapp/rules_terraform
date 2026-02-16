#!/usr/bin/env bash
set -euo pipefail

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

[[ -z ${BUILD_WORKSPACE_DIRECTORY-} ]] || export TF_DATA_DIR="$BUILD_WORKSPACE_DIRECTORY"/%{data_dir}

config=%{config}
[[ -z $config ]] || export TF_CLI_CONFIG_FILE="$(rlocation "$config")"

runfiles_dir="${RUNFILES_DIR-${RUNFILES_MANIFEST_FILE%_manifest}}"

exec "$(rlocation %{terraform})" -chdir="$runfiles_dir"/%{path} "$@"
