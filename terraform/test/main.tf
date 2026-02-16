terraform {
  required_providers {
    runfiles = {
      source = "redo.com/rules-terraform/runfiles"
    }
  }
}

provider "random" {
}

provider "runfiles" {
}

resource "random_id" "example" {
  byte_length = 8
  keepers = {
    data = file(provider::runfiles::rlocation("rules_terraform/terraform/test/data.txt"))
  }
}
