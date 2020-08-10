__________________________________________________________________________________________________________________
# AWS Elastic Kubernetes Services (EKS) Project:
__________________________________________________________________________________________________________________
Project completed under LinuxWorld Informatics Ltd. - AWS EKS Training and includes the EKS task containing multiple use cases like fargate, etc.
_________________________________________________________________________________________________________________
### Project Details:
_________________________________________________________________________________________________________________
AWS EKS Cluster is Created and WordPress (with MySQL Database) Infrastructure is Deployed on it using Terraform.
_________________________________________________________________________________________________________________
### Pre-requisite:
You need Kubectl, Terraform and AWSCLI installed.
_________________________________________________________________________________________________________________
### Login into AWS CLI:
_________________________________________________________________________________________________________________
You need to login into AWS CLI using "aws configure" command   

By default this Code will use Default AWS CLI Profile  
If you want to use any other profile then Update Profile in AWS Provider in this code
_________________________________________________________________________________________________________________
### Run the Code:
_________________________________________________________________________________________________________________
Create AWS EKS Cluster -  
Go inside EKS-Cluster Directory and run the following commands    
- terraform init  
- terraform apply   

Deploying Wordpress -   
Go into Infrastructure Directory and run the following commands  
- terraform init  
- terraform apply   

Note :- "terraform apply" command will ask you to approve it in between but you can use "terraform apply --auto-approve" command for auto approval
_________________________________________________________________________________________________________________
`Amazon Elastic Kubernetes Service (Amazon EKS) is a fully managed Kubernetes service. Kubernetes (K8s) is an open-source system for automating deployment, scaling, and management of containerized applications.`
_________________________________________________________________________________________________________________
- Here we'll create an AWS EKS Cluster and deploy WordPress App on it. We'll create this complete Infrastructure using Terraform.

- I've created two terraform codes one for creating complete EKS Cluster and another for deploying our WordPress on it.

- First of all, we will log in into AWS CLI and for this, we need to run this "aws configure" command.

- Now, First of all, Let's understand the terraform code for creating the EKS Cluster

- From the following code, we are creating Key-Pair and Security Group which we will use for Cluster Slave Nodes. Along with this, we have declared variable for VPC and also make a list of all the subnets present in our VPC
_________________________________________________________________________________________________________________
```
//Setting Up AWS Provider
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}


//Creating Variable for VPC
variable "vpc" {
  type    = string
  default = "vpc-e96e8d94"
}


//Creating Key
resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
}


//Generating Key-Value Pair
resource "aws_key_pair" "generated_key" {
  key_name   = "eks-key"
  public_key = "${tls_private_key.tls_key.public_key_openssh}"


  depends_on = [
    tls_private_key.tls_key
  ]
}


//Saving Private Key PEM File
resource "local_file" "key-file" {
  content  = "${tls_private_key.tls_key.private_key_pem}"
  filename = "eks-key.pem"


  depends_on = [
    tls_private_key.tls_key
  ]
}


//Creating Security Group For NodeGroups
resource "aws_security_group" "ng-sg" {
  name        = "node-group-sg"
  description = "Node Group SG"
  vpc_id      = var.vpc


  //Adding Rules to Security Group
  ingress {
    description = "SSH Rule"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "HTTP Rule"
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


//Getting all Subnet IDs of a VPC
data "aws_subnet_ids" "subnet" {
  vpc_id = var.vpc
}


data "aws_subnet" "subnets" {
  for_each = data.aws_subnet_ids.subnet.ids
  id       = each.value


  depends_on = [
    data.aws_subnet_ids.subnet
  ]
}
```
_________________________________________________________________________________________________________________
- This code will create an EKS Cluster in AWS and along with this it will also create IAM Role for EKS cluster and attach policies to it.
_________________________________________________________________________________________________________________

```
//Creating EKS Cluster
resource "aws_eks_cluster" "eks-cluster" {
  name     = "my-eks-cluster"
  role_arn = "${aws_iam_role.eks-role.arn}"


  vpc_config {
    subnet_ids = [for s in data.aws_subnet.subnets : s.id if s.availability_zone != "us-east-1e"]
  }


  depends_on = [
    aws_iam_role_policy_attachment.EKSClusterPolicy,
    aws_iam_role_policy_attachment.EKSServicePolicy,
    data.aws_subnet.subnets
  ]
}


//Creating IAM Role for EKS Cluster
resource "aws_iam_role" "eks-role" {
  name = "eks-cluster-role"


  //Writing Policy
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}


//Attaching Polices to IAM Role for EKS
resource "aws_iam_role_policy_attachment" "EKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks-role.name}"
}


resource "aws_iam_role_policy_attachment" "EKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks-role.name}"
}
```
_________________________________________________________________________________________________________________
- This code will create NodeGroups for us and also creates IAM Role for Nodegroups and attach Policies to it.  Node Group is an Amazon EC2 Auto Scaling group and associated Amazon EC2 instances that are managed by AWS for an Amazon EKS cluster.
_________________________________________________________________________________________________________________
```
//Creating a Node Group 1
resource "aws_eks_node_group" "ng1" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "node-group-1"
  node_role_arn   = aws_iam_role.ng-role.arn
  subnet_ids      = [for s in data.aws_subnet.subnets : s.id if s.availability_zone != "us-east-1e"]


  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }


  instance_types  = ["m5.xlarge"]


  remote_access {
    ec2_ssh_key = "eks-key"
    source_security_group_ids = [aws_security_group.ng-sg.id]
  }


  depends_on = [
    aws_iam_role_policy_attachment.EKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.EKS_CNI_Policy,
    aws_iam_role_policy_attachment.EC2ContainerRegistryReadOnly,
    aws_eks_cluster.eks-cluster
  ]
}


//Creating Node Group 2
resource "aws_eks_node_group" "ng2" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "node-group-2"
  node_role_arn   = aws_iam_role.ng-role.arn
  subnet_ids      = [for s in data.aws_subnet.subnets : s.id if s.availability_zone != "us-east-1e"]


  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }


  instance_types  = ["m5.large"]


  remote_access {
    ec2_ssh_key = "eks-key"
    source_security_group_ids = [aws_security_group.ng-sg.id]
  }


  depends_on = [
    aws_iam_role_policy_attachment.EKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.EKS_CNI_Policy,
    aws_iam_role_policy_attachment.EC2ContainerRegistryReadOnly,
    aws_eks_cluster.eks-cluster
  ]
}


//Created IAM Role for Node Groups
resource "aws_iam_role" "ng-role" {
  name = "eks-ng-role"


  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}


//Attaching Policies to IAM Role of Node Groups
resource "aws_iam_role_policy_attachment" "EKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ng-role.name
}


resource "aws_iam_role_policy_attachment" "EKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ng-role.name
}


resource "aws_iam_role_policy_attachment" "EC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ng-role.name
}
```
_________________________________________________________________________________________________________________
- Now after creating cluster we'll setup our Kubectl to use the EKS cluster. For this, we need to run "aws eks update-kubeconfig --name my-eks-cluster" command. Here I used terraform local-exec resource for doing this
_________________________________________________________________________________________________________________
```
//Updating Kubectl Config File
resource "null_resource" "update-kube-config" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name my-eks-cluster"
  }
  depends_on = [
    aws_eks_node_group.ng1,
    aws_eks_node_group.ng2
  ]
}
```
_________________________________________________________________________________________________________________
- Now after writing terraform code we'll run it using "terraform apply" command.
- After this, we can see that 15 resources are created, which includes Keys-Pairs, Security Groups, Cluster, NodeGroups, IAM Roles, Policies.
- And in EC2 we can see that two instances are running which are Slave Nodes of EKS Cluster -
- Also in AWS Portal, we can observe that Cluster and Node Groups are Active:-
_________________________________________________________________________________________________________________
*Now we are ready to Deploy our WordPress and MySQL Infrastructure on EKS Cluster. So Let's understand the Terraform Code for it*
_________________________________________________________________________________________________________________
The following Code will create a PVC (Persistence Volume Claim) for our Pods. This will make our WordPress and MySQL data persistence. On running, this will create EBS Volumes in AWS.
_________________________________________________________________________________________________________________
```
//Kubernetes Provider
provider "kubernetes" {
  //By Default works on Current Context
}


//Creating PVC for WordPress Pod
resource "kubernetes_persistent_volume_claim" "wp-pvc" {
  metadata {
    name   = "wp-pvc"
    labels = {
      env     = "Production"
      Country = "India"
    }
  }


  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}


//Creating PVC for MySQL Pod
resource "kubernetes_persistent_volume_claim" "MySqlPVC" {
  metadata {
    name   = "mysql-pvc"
    labels = {
      env     = "Production"
      Country = "India"
    }
  }


  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}
```
_________________________________________________________________________________________________________________
- This will create a Deployment for Our WordPress -
_________________________________________________________________________________________________________________
```
//Creating Deployment for WordPress
resource "kubernetes_deployment" "wp-dep" {
  metadata {
    name   = "wp-dep"
    labels = {
      env     = "Production"
      Country = "India"
    }
  }
  depends_on = [
    kubernetes_deployment.MySql-dep,
    kubernetes_service.MySqlService
  ]


  spec {
    replicas = 2
    selector {
      match_labels = {
        pod     = "wp"
        env     = "Production"
        Country = "India"

      }
    }


    template {
      metadata {
        labels = {
          pod     = "wp"
          env     = "Production"
          Country = "India"  
        }
      }


      spec {
        volume {
          name = "wp-vol"
          persistent_volume_claim {
            claim_name = "${kubernetes_persistent_volume_claim.wp-pvc.metadata.0.name}"
          }
        }


        container {
          image = "wordpress:4.8-apache"
          name  = "wp-container"


          env {
            name  = "WORDPRESS_DB_HOST"
            value = "${kubernetes_service.MySqlService.metadata.0.name}"
          }
          env {
            name  = "WORDPRESS_DB_USER"
            value = "user"
          }
          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = "resu"
          }
          env{
            name  = "WORDPRESS_DB_NAME"
            value = "wpdb"
          }
          env{
            name  = "WORDPRESS_TABLE_PREFIX"
            value = "wp_"
          }


          volume_mount {
              name       = "wp-vol"
              mount_path = "/var/www/html/"
          }


          port {
            container_port = 80
          }
        }
      }
    }
  }
}
```
_________________________________________________________________________________________________________________
- This will create a Deployment for our MySQL -
_________________________________________________________________________________________________________________
```
//Creating Deployment for MySQL Pod
resource "kubernetes_deployment" "MySql-dep" {
  metadata {
    name   = "mysql-dep"
    labels = {
      env     = "Production"
      Country = "India"
    }
  }


  spec {
    replicas = 1
    selector {
      match_labels = {
        pod     = "mysql"
        env     = "Production"
        Country = "India"
      }
    }


    template {
      metadata {
        labels = {
          pod     = "mysql"
          env     = "Production"
          Country = "India"
        }
      }


      spec {
        volume {
          name = "mysql-vol"
          persistent_volume_claim {
            claim_name = "${kubernetes_persistent_volume_claim.MySqlPVC.metadata.0.name}"
          }
        }


        container {
          image = "mysql:5.6"
          name  = "mysql-container"


          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "toor"
          }
          env {
            name  = "MYSQL_DATABASE"
            value = "wpdb"
          }
          env {
            name  = "MYSQL_USER"
            value = "user"
          }
          env{
            name  = "MYSQL_PASSWORD"
            value = "resu"
          }


          volume_mount {
              name       = "mysql-vol"
              mount_path = "/var/lib/mysql"
          }


          port {
            container_port = 80
          }
        }
      }
    }
  }
}
```
_________________________________________________________________________________________________________________
- The following code will create a service that will expose our WordPress container to public world so that clients can connect to it. This will create a LoadBalancer Service in AWS which will provide us an URL by which we can connect to the WordPress.
_________________________________________________________________________________________________________________
```
//Creating LoadBalancer Service for WordPress Pods
resource "kubernetes_service" "wpService" {
  metadata {
    name   = "wp-svc"
    labels = {
      env     = "Production"
      Country = "India"
    }
  }  


  depends_on = [
    kubernetes_deployment.wp-dep
  ]


  spec {
    type     = "LoadBalancer"
    selector = {
      pod = "wp"
    }


    port {
      name = "wp-port"
      port = 80
    }
  }
}

```
_________________________________________________________________________________________________________________
- This is again a Service but this is of ClusterIP type. This will expose our MySQL within the cluster only and due to this our WordPress will be able to connect to MySQL to store data in the database.
_________________________________________________________________________________________________________________
```
//Creating ClusterIP service for MySQL Pods
resource "kubernetes_service" "MySqlService" {
  metadata {
    name   = "mysql-svc"
    labels = {
      env     = "Production"
      Country = "India"
    }
  }  
  depends_on = [
    kubernetes_deployment.MySql-dep
  ]


  spec {
    selector = {
      pod = "mysql"
    }

    cluster_ip = "None"
    port {
      name = "mysql-port"
      port = 3306
    }
  }
}
```
_________________________________________________________________________________________________________________
- When LoadBalancer is created, It will Register the IP's of all Nodes in it. and Registering will take some time. So here we will create a terraform "time_sleep" resource due to which terraform code will be paused for 60 seconds and After this we have used "local-exec" provisioner to Open LoadBalancer URL Automatically.
_________________________________________________________________________________________________________________
```
//Wait For LoadBalancer to Register IPs
resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
  depends_on = [kubernetes_service.wpService]  
}


//Open Wordpress Site
resource "null_resource" "open_wp" {
  provisioner "local-exec" {
    command = "start chrome ${kubernetes_service.wpService.load_balancer_ingress.0.hostname}"
  }

  depends_on = [
    time_sleep.wait_60_seconds
  ]
}
```
_________________________________________________________________________________________________________________
- Again for running this code we will run the "terraform apply" command.
- And we can observe that 8 resources are created which includes Deployment, Service, PVCs
- We can run "kubectl get all" command to see Kubernetes Resources
- Now If we go to AWS, we can see that two more EBS volumes are created, these are the volumes that are mounted on WordPress and MySQL Pod to make their data Persistence. And if anyhow our Pods get deleted then they are restarted by deployment and again these same volumes are mounted on them which leads to No Data Loss
-LoadBalancer Service is also created in AWS.
_________________________________________________________________________________________________________________
`And Finally, Our WordPress is Working Well! Hence the Project is complete.`
_________________________________________________________________________________________________________________
### Author:
----------------------------------
```diff
+ Vedant Shrivastava | vedantshrivastava466@gmail.com
```
