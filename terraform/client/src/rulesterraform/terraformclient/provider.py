from __future__ import annotations
from dataclasses import dataclass
from urllib.error import HTTPError
from urllib.parse import urljoin
from urllib.request import Request, urlopen
from json import load
from typing import List
from .service_discovery import TerraformServiceDiscoveryClient


@dataclass
class TerraformPlatform:
    arch: str
    os: str


@dataclass
class TerraformProviderPackage:
    download_url: str
    filename: str
    platform: TerraformPlatform
    shasum: str
    shasums_signature_url: str
    shasums_url: str


@dataclass
class TerraformProviderVersion:
    platforms: List[TerraformPlatform]
    version: str


class TerraformProviderClient:
    def __init__(self, url: str):
        self._url = url

    def get_package(
        self, namespace: str, type: str, version: str, platform: TerraformPlatform
    ) -> TerraformProviderPackage:
        url = urljoin(
            self._url,
            f"{namespace}/{type}/{version}/download/{platform.os}/{platform.arch}",
        )
        request = Request(url, headers={"Accept": "application/json"})
        response = urlopen(request)
        try:
            result = load(response)
        except HTTPError:
            if e.code == 404:
                raise TerraformProviderPackageNotFoundError()

        return TerraformProviderPackage(
            download_url=result["download_url"],
            filename=result["filename"],
            platform=TerraformPlatform(arch=result["arch"], os=result["os"]),
            shasum=result["shasum"],
            shasums_signature_url=result["shasums_signature_url"],
            shasums_url=result["shasums_url"],
        )

    def list_versions(
        self, namespace: str, type: str
    ) -> List[TerraformProviderVersion]:
        url = urljoin(self._url, f"{namespace}/{type}/versions")
        request = Request(url, headers={"Accept": "application/json"})
        try:
            response = urlopen(request)
        except HTTPError as e:
            if e.code == 404:
                return []
            raise
        result = load(response)

        return [
            TerraformProviderVersion(
                platforms=[
                    TerraformPlatform(arch=platform["arch"], os=platform["os"])
                    for platform in version.get("platforms", [])
                ],
                version=version["version"],
            )
            for version in result["versions"]
        ]

    @classmethod
    def discover(self, service_discovery_client: TerraformServiceDiscoveryClient):
        services = service_discovery_client.get()
        try:
            url = services["providers.v1"]
        except KeyError:
            raise RuntimeError("Does not support providers.v1 service")
        return self(url)
