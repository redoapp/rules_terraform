from json import dump
from rulesterraform.terraformclient.provider import TerraformProviderClient
from rulesterraform.terraformclient.service_discovery import (
    TerraformServiceDiscoveryClient,
)
from sys import stderr


def resolve(providers, out, registry=None):
    print("PROVIDERS = {", file=out)

    for name, provider in providers:
        print(f'    "{name}": struct(', file=out)

        print("        platforms = {", file=out)
        discovery_client = TerraformServiceDiscoveryClient(
            f"https://{registry or provider.hostname}"
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
            print(f'            "{platform.os}_{platform.arch}": struct(', file=out)
            print(f'                sha256 = "{package.shasum}",', file=out)
            print(f'                url = "{package.download_url}",', file=out)
            print(f"            ),", file=out)
        print("        },", file=out)

        print(f'        hostname = "{provider.hostname}",', file=out)
        print(f'        namespace = "{provider.namespace}",', file=out)
        print(f'        type = "{provider.type}",', file=out)
        print(f'        version = "{provider.version}",', file=out)

        print("    ),", file=out)
        print(f"Resolved {name}", file=stderr)

    print("}", file=out)
