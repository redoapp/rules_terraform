__package__ = "rulesterraform.terraformresolve"

from argparse import ArgumentParser
from dataclasses import dataclass
from sys import stdout


@dataclass
class TerraformProviderVersion:
    hostname: str
    namespace: str
    type: str
    version: str


def provider_arg(string):
    name, value = string.split("=")
    hostname, namespace, type, version = value.split("/")
    return name, TerraformProviderVersion(
        hostname=hostname, namespace=namespace, type=type, version=version
    )


parser = ArgumentParser(prog="terraform-resolve")
parser.add_argument("--registry", help="")
parser.add_argument(
    "providers",
    metavar="NAME=HOSTNAME/NAMESPACE/TYPE/VERSION",
    nargs="*",
    type=provider_arg,
)
args = parser.parse_args()

from .resolve import resolve

resolve(providers=args.providers, registry=args.registry, out=stdout)
