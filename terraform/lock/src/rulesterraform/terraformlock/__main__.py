from argparse import ArgumentParser
from pathlib import Path

parser = ArgumentParser()
parser.add_argument("--platform", required=True)
parser.add_argument("--provider", action="append", default=[])
parser.add_argument("--providers", required=True, type=Path)
parser.add_argument("--terraform", required=True, type=Path)
parser.add_argument("out", type=Path)
args = parser.parse_args()

from json import dumps
from subprocess import run
from tempfile import TemporaryDirectory

with TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    with (tmp / "main.tf").open("w") as f:
        print("terraform {", file=f)
        print("  required_providers {", file=f)
        for i, provider in enumerate(args.provider):
            source, version = provider.rsplit("/", 1)
            print(
                f"    provider{i + 1} = {{ source = {dumps(source)}, version = {dumps(version)} }}",
                file=f,
            )
        print("  }", file=f)
        print("}", file=f)
    run(
        [
            args.terraform.absolute(),
            "providers",
            "lock",
            f"-fs-mirror={args.providers.absolute()}",
            f"-platform={args.platform}",
        ],
        cwd=tmp,
    )
    (tmp / ".terraform.lock.hcl").rename(args.out)
