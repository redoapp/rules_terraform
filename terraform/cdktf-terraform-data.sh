synth="$1"
out="$2"
stack="$3"

rm -fr "$out"
cp -r "$synth"/stacks/"$stack" "$out"
