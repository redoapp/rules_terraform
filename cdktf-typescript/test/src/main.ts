import { Id } from "@cdktf/provider-random/lib/id";
import { RandomProvider } from "@cdktf/provider-random/lib/provider";
import { rlocation } from "@rules-terraform/runfiles/lib/function-rlocation";
import { RunfilesProvider } from "@rules-terraform/runfiles/lib/provider";
import { App, Fn, LocalBackend, TerraformStack } from "cdktf";

const app = new App();

const stack = new TerraformStack(app, "Main");

new LocalBackend(stack, {
  path: "terraform.tfstate",
});

new RandomProvider(stack, "random");

new RunfilesProvider(stack, "runfiles");

new Id(stack, "id", {
  byteLength: 8,
  keepers: {
    data: Fn.file(rlocation("rules_terraform/cdktf-typescript/test/data.txt")),
  },
});

app.synth();
