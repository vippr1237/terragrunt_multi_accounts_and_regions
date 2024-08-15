terraform {
  source = "tfr:///terraform-aws-modules/ecs/aws//modules/service?version=5.11.1"
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("global.hcl"))
  regional_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  project_name = local.global_vars.locals.project_name
  aws_region   = local.regional_vars.locals.aws_region

  service_name   = "${local.project_name}-ecsdemo-frontend"
  container_name = "${local.project_name}-ecsdemo-frontend"
  container_port = 3000
}

dependency "vpc" {
  config_path = "../../vpc"
  mock_outputs                            = {
    vpc_id = "vpc-123456"
    public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    vpc_cidr_block = "10.0.0.0/16"
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  }
}

dependency "alb" {
  config_path = "../../alb"
  mock_outputs = {
    target_groups = {
      ex_ecs = {
        arn = "arn:aws:ec2:us-east-1:123456789012:mock/mock"
      }
    },
    security_group_id = "mock-123"
  }
}

dependency "ecs_cluster" {
  config_path = "../../ecs-cluster"
  mock_outputs = {
    arn = "arn:aws:ec2:us-east-1:123456789012:mock/mock"
  }
}

inputs = {
  cluster_name = "${local.project_name}-fargate"

  name        = local.service_name
  cluster_arn = dependency.ecs_cluster.outputs.arn

  cpu    = 1024
  memory = 4096

  # Enables ECS Exec
  enable_execute_command = true

  # Container definition(s)
  container_definitions = {

    (local.container_name) = {
      cpu       = 512
      memory    = 1024
      essential = true
      image     = "public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50"
      port_mappings = [
        {
          name          = local.container_name
          containerPort = local.container_port
          hostPort      = local.container_port
          protocol      = "tcp"
        }
      ]

      # Example image used requires access to write to root filesystem
      readonly_root_filesystem = false

      enable_cloudwatch_logging = true

      linux_parameters = {
        capabilities = {
          add = []
          drop = [
            "NET_RAW"
          ]
        }
      }
      memory_reservation = 100
    }
  }

  load_balancer = {
    service = {
      target_group_arn = dependency.alb.outputs.target_groups["ex_ecs"].arn
      container_name   = local.container_name
      container_port   = local.container_port
    }
  }

  subnet_ids = dependency.vpc.outputs.private_subnets
  security_group_rules = {
    alb_ingress_3000 = {
      type                     = "ingress"
      from_port                = local.container_port
      to_port                  = local.container_port
      protocol                 = "tcp"
      description              = "Service port"
      source_security_group_id = dependency.alb.outputs.security_group_id
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}