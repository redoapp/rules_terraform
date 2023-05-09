#!/usr/bin/env bash
set -euo pipefail

if [ -z "${RUNFILES_DIR-}" ]; then
  if [ ! -z "${RUNFILES_MANIFEST_FILE-}" ]; then
    export RUNFILES_DIR="${RUNFILES_MANIFEST_FILE%.runfiles_manifest}.runfiles"
  else
    export RUNFILES_DIR="$0.runfiles"
  fi
fi

[[ "$RUNFILES_DIR" == /* ]] || RUNFILES_DIR="$(pwd)"/"$RUNFILES_DIR"

[ -z "${BUILD_WORKSPACE_DIRECTORY-}" ] || export TF_DATA_DIR="$BUILD_WORKSPACE_DIRECTORY"/%{data_dir}

export TF_VAR_runfiles_dir="$RUNFILES_DIR"

cd "$RUNFILES_DIR"/%{path}

exec "$RUNFILES_DIR"/%{terraform} "$@"
