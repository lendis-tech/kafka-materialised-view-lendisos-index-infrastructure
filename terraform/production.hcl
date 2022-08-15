bucket         = "lendis-helm-chart-production-terraform-state-bucket"
key            = "kafka-materialised-view-lendisos-index-production/terraform.tfstate"
region         = "eu-central-1"
encrypt        = true
dynamodb_table = "lendis-helm-chart-production-terraform-state-lock-table"