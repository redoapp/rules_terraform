from argparse import ArgumentParser

parser = ArgumentParser(prog="terraform-resolve-tf")
parser.add_argument("--version", action="append", default=[], dest="versions")
args = parser.parse_args()

from json import dumps
from urllib.parse import urljoin
from urllib.request import Request, urlopen
from sys import stderr
from typing import Dict

base_url = "https://releases.hashicorp.com/terraform/"

print("TERRAFORM = {")

for version in args.versions:
    print(f"    {dumps(version)}: {{")
    url = urljoin(base_url, f"{version}/terraform_{version}_SHA256SUMS")
    with urlopen(url) as response:
        for line in response:
            digest, file = line.decode("utf-8").split("  ")
            platform = file[len(f"terraform_{version}_") : -len(".zip") - 1]
            print(f"        {dumps(platform)}: struct(")
            print(f"            sha256 = {dumps(digest)},")
            print("        ),")
    print("    },")
    print(f"Resolved {version}", file=stderr)
print("}")
