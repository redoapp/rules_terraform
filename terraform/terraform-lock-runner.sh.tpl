#!/usr/bin/env bash
set -euo pipefail

if [ -z "${RUNFILES_DIR-}" ]; then
  if [ ! -z "${RUNFILES_MANIFEST_FILE-}" ]; then
    export RUNFILES_DIR="${RUNFILES_MANIFEST_FILE%.runfiles_manifest}.runfiles"
  else
    export RUNFILES_DIR="$0.runfiles"
  fi
fi


function finish {
  [ -z "${tmp-}" ] || true || rm -fr "$tmp"
}
trap finish EXIT

tmp="$(mktemp -d)"

cp -r "$RUNFILES_DIR" "$tmp"/tmp.runfiles
chmod 755 "$tmp"/tmp.runfiles/%{path}

RUNFILES_DIR="$tmp"/tmp.runfiles "$tmp"/tmp.runfiles/%{terraform} providers lock

chmod 664 "$tmp"/tmp.runfiles/%{path}/.terraform.lock.hcl
mv "$tmp"/tmp.runfiles/%{path}/.terraform.lock.hcl "$BUILD_WORKING_DIRECTORY"/%{output}
