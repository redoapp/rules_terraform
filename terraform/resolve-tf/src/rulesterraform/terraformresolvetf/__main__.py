__package__ = "rulesterraform.terraformresolvetf"

from argparse import ArgumentParser
from sys import stdout

parser = ArgumentParser(prog="terraform-resolve-tf", description="Resolve Terraform versions")
parser.add_argument("--version", action="append", default=[], dest="versions", help="Version")
args = parser.parse_args()

from .resolve_tf import resolve_tf

resolve_tf(out=stdout, versions=args.versions)
