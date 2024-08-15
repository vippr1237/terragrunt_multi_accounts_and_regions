include "root" {
  path = find_in_parent_folders("main.hcl")
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../common_resources/frontend.hcl"
}

inputs = {
}