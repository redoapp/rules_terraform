import {
  asString,
  stringValue,
  terraformFunction,
} from "cdktf/lib/functions/helpers";

export function rlocationFrom(path: string, requestingRepo: string): string {
  return asString(
    terraformFunction("provider::runfiles::rlocation_from", [
      stringValue,
      stringValue,
    ])(path, requestingRepo),
  );
}
