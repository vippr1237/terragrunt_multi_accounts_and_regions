include "root" {
  path = find_in_parent_folders("main.hcl")
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../common_resources/vpc.hcl"
}

inputs = {
  azs  = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}
