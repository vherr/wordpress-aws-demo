output "db_address" {
  value = aws_db_instance.default.address
}

output "ecr_repository" {
  value = "${aws_ecr_repository.wordpress-ecr.repository_url}:${var.docker_tag}"
}
