from collections.abc import Iterator
from json import dumps
from pathlib import Path
from shutil import move
from subprocess import CalledProcessError, check_output, STDOUT
from sys import getdefaultencoding, exit
from tempfile import TemporaryDirectory
from typing import Tuple


def _providers(path: Path) -> Iterator[Tuple[str, str]]:
    for hostname_path in path.iterdir():
        for namespace_path in hostname_path.iterdir():
            for type_path in namespace_path.iterdir():
                source = str(type_path.relative_to(path))
                for version_path in type_path.iterdir():
                    version = str(version_path.relative_to(type_path))
                    yield source, version


def lock(platform: str, providers: Path, terraform: Path, out: Path):
    with TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        with (tmp / "main.tf").open("w") as f:
            print("terraform {", file=f)
            print("  required_providers {", file=f)
            for i, (source, version) in enumerate(_providers(providers), 1):
                print(
                    f"    provider{i} = {{ source = {dumps(source)}, version = {dumps(version)} }}",
                    file=f,
                )
            print("  }", file=f)
            print("}", file=f)
        try:
            check_output(
                [
                    terraform.absolute(),
                    "providers",
                    "lock",
                    f"-fs-mirror={providers.absolute()}",
                    f"-platform={platform}",
                ],
                cwd=tmp,
                encoding=getdefaultencoding(),
                stderr=STDOUT,
            )
        except CalledProcessError as e:
            exit(f"terraform providers lock: {e.returncode}\n{e.output}")
        move(tmp / ".terraform.lock.hcl", out)
