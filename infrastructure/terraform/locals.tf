locals {
  project = "umami"
  tags = {
    "provisioner" = "terraform"
    "project"     = local.project
  }
}
