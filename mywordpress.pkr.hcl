variable "ecr-repo" {
  type = string
  default = "<AWS_ECR_REPO_URL>"
}

source "docker" "mywordpress" {
  image = "ubuntu"
  commit = true
  changes = [
    "CMD [\"/opt/entrypoint.sh\"]"
  ]
}

build {
  sources = ["source.docker.mywordpress"]
  
  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y ansible",
   ]
  }

  provisioner "ansible-local" {
    playbook_file = "./ansible/playbook.yml"
    playbook_dir = "./ansible"
  }
  
  provisioner "shell" {
    inline = [
      "apt-get remove -y ansible",
      "apt-get autoremove -y"
    ]
  }

  post-processors {
    post-processor "docker-tag" {
      repository = var.ecr-repo
      tags = ["mywordpress"]
    }
    post-processor "docker-push" {
      ecr_login = true
      login_server = var.ecr-repo
    }
  }

}
