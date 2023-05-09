from argparse import ArgumentParser
from dataclasses import dataclass


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

from json import dump
from rulesterraform.terraformclient.provider import TerraformProviderClient
from rulesterraform.terraformclient.service_discovery import (
    TerraformServiceDiscoveryClient,
)
from sys import stderr, stdout

print("PROVIDERS = {")

for name, provider in args.providers:
    print(f'    "{name}": struct(')

    print("        platforms = {")
    discovery_client = TerraformServiceDiscoveryClient(
        f"https://{args.registry or provider.hostname}"
    )
    client = TerraformProviderClient.discover(discovery_client)

    versions = client.list_versions(provider.namespace, provider.type)
    for version in versions:
        if version.version == provider.version:
            break
    else:
        raise RuntimeError(f"{provider} not found")

    for platform in version.platforms:
        package = client.get_package(
            provider.namespace, provider.type, provider.version, platform
        )
        print(f'            "{platform.os}_{platform.arch}": struct(')
        print(f'                sha256 = "{package.shasum}",')
        print(f'                url = "{package.download_url}",')
        print(f"            ),")
    print("        },")

    print(f'        hostname = "{provider.hostname}",')
    print(f'        namespace = "{provider.namespace}",')
    print(f'        type = "{provider.type}",')
    print(f'        version = "{provider.version}",')

    print("    ),")
    print(f"Resolved {name}", file=stderr)

print("}")
