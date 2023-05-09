synth="$1"
out="$2"
stack="$3"

cp -r "$synth"/stacks/"$stack"/cdk.tf.json "$out"
