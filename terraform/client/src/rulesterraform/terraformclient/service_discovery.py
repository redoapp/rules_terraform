from json import load
from urllib.parse import urljoin
from urllib.request import Request, urlopen
from typing import Dict


class TerraformServiceDiscoveryClient:
    def __init__(self, url):
        self._url = url

    def get(self) -> Dict[str, str]:
        url = urljoin(self._url, "/.well-known/terraform.json")
        request = Request(url, headers={"Accept": "application/json"})
        response = urlopen(request)
        return {key: urljoin(self._url, value) for key, value in load(response).items()}
