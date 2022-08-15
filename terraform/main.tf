terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.14.0"
    }
  }
}

terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

resource "aws_iam_role" "service_account_role" {
  name = var.service_account_name
  path = "/"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Principal" : {
        "Federated" : data.aws_iam_openid_connect_provider.openid_connect_provider.arn
      },
      "Action" : "sts:AssumeRoleWithWebIdentity",
      "Condition" : {
        "StringEquals" : {
          "${data.aws_iam_openid_connect_provider.openid_connect_provider.url}:sub" : "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}",
          "${data.aws_iam_openid_connect_provider.openid_connect_provider.url}:aud" : "sts.amazonaws.com"
        }
      }
    }]
  })

  dynamic "inline_policy" {
    for_each = local.inline_policies

    content {
      name   = inline_policy.value.name
      policy = inline_policy.value.policy
    }
  }
}
