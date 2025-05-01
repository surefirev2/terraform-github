terraform {
  backend "http" {
    address        = "https://api.tfstate.dev/github/v1"
    lock_address   = "https://api.tfstate.dev/github/v1/lock"
    unlock_address = "https://api.tfstate.dev/github/v1/lock"
    lock_method    = "PUT"
    unlock_method  = "DELETE"
    username       = "surefirev2/template-1-terraform"
  }
}

resource "local_file" "hello_world" {
  content  = "Hello, World!"
  filename = "${path.module}/hello_world.txt"
}
