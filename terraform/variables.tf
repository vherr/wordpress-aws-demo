variable "region" {
  default = "eu-west-3"
}

variable "ecr_name" {
  default = "wordpress-repo"
}

variable "cluster_name" {
  default = "wordpress-cluster"
}

variable "docker_tag" {
  default = "mywordpress"
}

variable "cpu_u" {
  default = 256
}

variable "memory" {
  default = 512
}

variable "db_name" {
  default = "wordpressdb"
}

variable "db_username" {
  default = "word"
}

variable "db_password" {
  default = "W0rdpr3ss"
}
