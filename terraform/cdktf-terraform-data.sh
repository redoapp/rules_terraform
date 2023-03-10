synth="$1"
out="$2"
stack="$3"
lock="$4"

rm -fr "$out"
cp -r "$synth"/stacks/"$stack" "$out"
cp "$lock" "$out"/.terraform.lock.hcl
