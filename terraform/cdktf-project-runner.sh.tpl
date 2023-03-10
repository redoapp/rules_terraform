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

export PATH="$PATH":"$RUNFILES_DIR"/_path

export CHECKPOINT_DISABLE=true
export DISABLE_VERSION_CHECK=true

cd "$RUNFILES_DIR"/%{path}

exec "$RUNFILES_DIR"/%{cdktf} -a "$RUNFILES_DIR"/%{bin} "$@"
