__package__ = "rulesterraform.terraformlock"

from argparse import ArgumentParser
from pathlib import Path

parser = ArgumentParser(prog="terraform-lock", description="Create Terraform lock file")
parser.add_argument("--platform", help="Platform", required=True)
parser.add_argument("--providers", help="Providers path", required=True, type=Path)
parser.add_argument(
    "--terraform", help="Terraform binary path", required=True, type=Path
)
parser.add_argument("out", help="Output path", type=Path)
args = parser.parse_args()

from .lock import lock

lock(
    platform=args.platform,
    providers=args.providers,
    terraform=args.terraform,
    out=args.out,
)
