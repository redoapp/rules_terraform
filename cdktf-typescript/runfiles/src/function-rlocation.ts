import {
  asString,
  stringValue,
  terraformFunction,
} from "cdktf/lib/functions/helpers";

export function rlocation(path: string): string {
  return asString(
    terraformFunction("provider::runfiles::rlocation", [stringValue])(path),
  );
}
