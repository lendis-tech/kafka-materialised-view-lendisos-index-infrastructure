bucket         = "lendis-helm-chart-staging2-terraform-state-bucket"
key            = "kafka-materialised-view-lendisos-index-staging2/terraform.tfstate"
region         = "eu-central-1"
encrypt        = true
dynamodb_table = "lendis-helm-chart-staging2-terraform-state-lock-table"
