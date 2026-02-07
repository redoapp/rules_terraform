provider "random" {
}

resource "random_id" "example" {
  byte_length = 8
}
