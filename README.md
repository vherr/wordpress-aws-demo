# Demo based on aws/terraform/packer/ansible/docker

## About

Purpose of this project is to setup a ready to use wordpress docker image deployed on aws ECS connected to a RDS database.

## Prepare environment 

To be able to run it, you have to install on your local machine: 
- docker 
- packer 
- terraform

As it's based on AWS, you will need your secret and access keys.

## Run

First, configure your AWS environement variables:
```
$ export AWS_ACCESS_KEY_ID=<ACCESS_KEY>
$ export AWS_SECRET_ACCESS_KEY=<SECRET_KEY>
```

Clone this project and deploy infrastructre with terraform:
```
$ cd terraform
$ terraform init
$ terraform apply
```
When it's finished, output will tell you the RDS address and Amazon ECR repository url:
```
[...]
Apply complete! Resources: 16 added, 0 changed, 0 destroyed.

Outputs:

db_address = "terraform-XXXXXX.eu-west-3.rds.amazonaws.com"
ecr_repository = "000XXX.dkr.ecr.eu-west-3.amazonaws.com/wordpress-repo:mywordpress"
```

Before generating docker image, modify "ansible/group_vars/all" and "mywordpress.pkr.hcl" accordingly to your terraform output.
- ansible/group_vars/all
```
db_host: aws_ecr_repo
```
- mywordpress.pkr.hcl
```
variable "ecr-repo" {
  type = string
  default = "<AWS_ECR_REPO_URL>"
}
```
Packer build will generate and deploy a docker image to AWS ECR repository
```
packer build mywordpress.pkr.hcl
```
Now you can now browse the public IP of your ECS cluster and finish wordpress setup.

## How it works

```
                              +----------------+
                              |User Browser    |
                              |                |
                              |                |
                              +-------+--------+
                                      |
                                      |http
                          +--------------------------------------------------+
                          |AWS        |                                      |
                          |           |                                      |
                          |  +--------v--------------+                       |
                          |  |ECS fargate            |        +-----------+  |
                          |  |                       |        | RDS       |  |
+------------+            |  |   +-------------+     |  sql   |           |  |
|            |            |  |   |Docker       +-------------->           |  |
|  Terraform +----------->+  |   |             |     |        |           |  |
|            |            |  |   +------+------+     |        |           |  |
+------------+            |  |          |            |        +-----------+  |
                          |  |          |            |                       |
                          |  +-----------------------+                       |
+------------+            |             |pull image                          |
|            |            |             |                                    |
|   Packer   |            |      +------v--------+                           |
|            |            |      |ECR            |                           |
+-----+------+            |      |               |                           |
      |                   |      +-------^-------+                           |
      |                   |              |                                   |
+-----v------+            +--------------------------------------------------+
|Docker      |                           |
+-----+------+                           |
      |                                  |
      |                                  |
+-----v-------+                          |
|ansible      |    push image            |
|             +--------------------------+
+-------------+

```

Terraform will be responsible to create all the infra we need for our project:
- VPC
- Subnet
- Routing
- Security groups
- ECR creation
- ECS cluster fargate
- ECS service and task 
- RDS instance

Packer will execute the following tasks:
- Generate a docker image
- Execute ansible 
  - Install ngnix web server 
  - Install php-fpm as wordpress engine is in PHP
  - Download wordpress
  - Assign db variables to wordpress configuration file
  - Install supervisor to run ngnix and php-fpm at start
- Remove uneeded package after install
- Docker tag and push to ECR

### What problems did I encounter 

Problems I encouter was were linked to ECR:
- Cannot pull container because I have forgotten the tag in the URL
- Cannot pull container because I didn't setup an internet gateway

### Improvment ideas

We have multiple definition of databases variables (in ansible and in terraform). A quick fix could be to use environment variables.
Password are stored in text file, we can use a vault to secure them and be API friendly.
We could also reduce the image size by using another linux distribution.

### Production concideration
 
This project is not aim to run in production, we have multiple risks:
- Website is in HTTP, a malicious user listening on the network can see our wordpress password admin account
- No HA. Concider using multiple wordpress instances, autoscaling group, load balancing ECS..
- No logs. Cloudwatch Logs can be use or a elasticsearch/kibana..
- We don't have monitoring/alerting. We can rely on datadog products or open-source products (zabbix, nagios, grafana/prometheus..)
- Configure a CI/CD pipeline for automatic build/unit test/deployment
- Use DNS with Route53
- For security, a WAF can be added
