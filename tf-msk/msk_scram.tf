resource "aws_msk_scram_secret_association" "msk_cluster_scram_assoc" {
  cluster_arn     = aws_msk_cluster.msk_cluster_scram.arn
  secret_arn_list = [aws_secretsmanager_secret.scram_auth_secret.arn]

  depends_on = [aws_secretsmanager_secret_version.scram_auth_secret_version]
}

resource "aws_secretsmanager_secret" "scram_auth_secret" {
  name       = "AmazonMSK_example"
  kms_key_id = aws_kms_key.scram_auth_key.key_id
}

resource "aws_kms_key" "scram_auth_key" {
  description = "Example Key for MSK Cluster Scram Secret Association"
}

resource "aws_secretsmanager_secret_version" "scram_auth_secret_version" {
  secret_id     = aws_secretsmanager_secret.scram_auth_secret.id
  secret_string = jsonencode({ username = "tierlenticar", password = "RReNJ6Q6&*8n9q&x35Tjuk*9" })
}

resource "aws_secretsmanager_secret_policy" "scram_auth_secret_policy" {
  secret_arn = aws_secretsmanager_secret.scram_auth_secret.arn
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Sid : "AWSKafkaResourcePolicy",
        Effect : "Allow",
        Principal : {
          "Service" : "kafka.amazonaws.com"
        },
        Action : "secretsmanager:getSecretValue",
        Resource : aws_secretsmanager_secret.scram_auth_secret.arn
    }]
  })
}

resource "aws_iam_policy" "eks_client_secretmanager_policy" {
  name = "EksScramSecretManagerPolicy"
  path = "/"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Effect : "Allow",
        Action : "secretsmanager:getSecretValue",
        Resource : aws_secretsmanager_secret.scram_auth_secret.arn
      }
    ]
  })
}

resource "aws_msk_configuration" "mks_config_scram" {
  kafka_versions = [
    "2.8.0"
  ]
  name = "demo-mks-config-scram"

  server_properties = <<PROPERTIES
auto.create.topics.enable = true
delete.topic.enable = true
PROPERTIES
}

resource "aws_msk_cluster" "msk_cluster_scram" {
  cluster_name           = var.cluster_name_scram
  kafka_version          = "2.8.0"
  number_of_broker_nodes = 2
  configuration_info {
    arn      = aws_msk_configuration.mks_config_scram.arn
    revision = 1
  }

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    ebs_volume_size = 120
    client_subnets = [
      aws_subnet.subnet_az2.id,
      aws_subnet.subnet_az3.id
    ]
    security_groups = [
      aws_security_group.sg.id
    ]
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.kms.arn
  }

  client_authentication {
    sasl {
      scram = true
    }
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.test.name
      }
    }
  }

  tags = {
    Name = "Amazon MSK Demo Cluster SASL/SCRAM"
  }
}
