terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "sub1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "sub2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}b"
}

resource "aws_route" "r" {
  route_table_id         = aws_vpc.main.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_iam_policy" "ecs_task_execution_policy" {
  name = "ecs-execution-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-execution-role"
  assume_role_policy = jsonencode({

    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "role-policy-attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
}

# create ecr repository
resource "aws_ecr_repository" "wordpress-ecr" {
  name = var.ecr_name
}

# create ecs cluster
resource "aws_ecs_cluster" "wordpress-ecs" {
  name = var.cluster_name
}

resource "aws_ecs_task_definition" "wordpress-task" {
  family = "wordpress-task"
  container_definitions = jsonencode([
    {
      "name" : "docker-wordpress",
      "image" : "${aws_ecr_repository.wordpress-ecr.repository_url}:${var.docker_tag}",
      "cpu" : var.cpu_u,
      "memory" : var.memory
    }
  ])
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu_u
  memory                   = var.memory
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_security_group" "frontend" {
  name   = "wordpress front"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "wordpress-service" {
  name                 = "wordpress_service"
  cluster              = aws_ecs_cluster.wordpress-ecs.id
  task_definition      = aws_ecs_task_definition.wordpress-task.arn
  desired_count        = 1
  launch_type          = "FARGATE"
  force_new_deployment = true
  network_configuration {
    subnets          = [aws_subnet.sub1.id, aws_subnet.sub2.id]
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = true
  }
}
# security group for rds instance
resource "aws_security_group" "backend" {
  name   = "backend db"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "wordrdssub" {
  name       = "word_rds_sub"
  subnet_ids = [aws_subnet.sub1.id, aws_subnet.sub2.id]
}

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  engine                 = "mariadb"
  instance_class         = "db.t2.micro"
  name                   = var.db_name
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.backend.id]
  db_subnet_group_name   = aws_db_subnet_group.wordrdssub.id
  skip_final_snapshot    = true
}
