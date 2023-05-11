from json import dumps
from urllib.parse import urljoin
from urllib.request import Request, urlopen
from sys import stderr
from typing import Dict

base_url = "https://releases.hashicorp.com/terraform/"


def resolve_tf(versions, out):
    print("TERRAFORM = {", file=out)
    for version in versions:
        print(f"    {dumps(version)}: {{", file=out)
        url = urljoin(base_url, f"{version}/terraform_{version}_SHA256SUMS")
        with urlopen(url) as response:
            for line in response:
                digest, file = line.decode("utf-8").split("  ")
                platform = file[len(f"terraform_{version}_") : -len(".zip") - 1]
                print(f"        {dumps(platform)}: struct(", file=out)
                print(f"            sha256 = {dumps(digest)},", file=out)
                print("        ),", file=out)
        print("    },", file=out)
        print(f"Resolved {version}", file=stderr)
    print("}", file=out)
