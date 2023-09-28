# ---------- AWS credentials ---------- #

terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

# ---------- Network/Security configuration ---------- #

# AWS Availability Zones data
data "aws_availability_zones" "available" {}

# Create the VPC
resource "aws_vpc" "redshift-vpc" {
  cidr_block           = var.redshift_vpc_cidr
  enable_dns_hostnames = true
  
  tags = {
    Name        = "redshift-vpc"
    Environment = var.app_environment
  }
}

# Create the Redshift Subnet AZ1
resource "aws_subnet" "redshift-subnet-az1" {
  vpc_id            = aws_vpc.redshift-vpc.id
  cidr_block        = var.redshift_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = {
    Name        = "redshift-subnet-az1"
    Environment = var.app_environment
  }
}

# Create the Redshift Subnet AZ2
resource "aws_subnet" "redshift-subnet-az2" {
  vpc_id            = aws_vpc.redshift-vpc.id
  cidr_block        = var.redshift_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  
  tags = {
    Name        = "redshift-subnet-az2"
    Environment = var.app_environment
  }
}

# Create the Redshift Subnet Group
resource "aws_redshift_subnet_group" "redshift-subnet-group" {
  depends_on = [
    aws_subnet.redshift-subnet-az1,
    aws_subnet.redshift-subnet-az2,
  ]

  name       = "redshift-subnet-group"
  subnet_ids = [aws_subnet.redshift-subnet-az1.id, aws_subnet.redshift-subnet-az2.id]

  tags = {
    Name        = "redshift-subnet-group"
    Environment = var.app_environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "redshift-igw" {
  vpc_id = aws_vpc.redshift-vpc.id

  tags = {
    Name        = "redshift-igw"
    Environment = var.app_environment
  }
}

# Define the redshift route table to Internet Gateway
resource "aws_route_table" "redshift-rt-igw" {
  vpc_id = aws_vpc.redshift-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.redshift-igw.id
  }  

  tags = {
    Name        = "redshift-public-route-igw"
    Environment = var.app_environment
  }
}

# Assign the redshift route table to the redshift Subnet az1 for IGW 
resource "aws_route_table_association" "redshift-subnet-rt-association-igw-az1" {
  subnet_id      = aws_subnet.redshift-subnet-az1.id
  route_table_id = aws_route_table.redshift-rt-igw.id
}

# Assign the public route table to the redshift Subnet az2 for IGW 
resource "aws_route_table_association" "redshift-subnet-rt-association-igw-az2" {
  subnet_id      = aws_subnet.redshift-subnet-az2.id
  route_table_id = aws_route_table.redshift-rt-igw.id
}

# Create Security Group
resource "aws_default_security_group" "redshift_security_group" {
  depends_on = [aws_vpc.redshift-vpc]
  
  vpc_id = aws_vpc.redshift-vpc.id
  
  ingress {
    description = "Redshift Port"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  
  tags = {
    Name        = "redshift-security-group"
    Environment = var.app_environment
  }
}

# Create IAM Role 
resource "aws_iam_role" "redshift-role" {
  name = "redshift-role"
  assume_role_policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
})


 tags = {
    Name        = "redshift-role"
    Environment = var.app_environment
  }
}

# Create IAM Policy 
resource "aws_iam_role_policy" "redshift-s3-full-access-policy" {
  name = "red_shift_s3_full_access_policy"
  role = aws_iam_role.redshift-role.id

policy = jsonencode({
   "Version": "2012-10-17",
   "Statement": [
     {
       "Effect": "Allow",
       "Action": "s3:*",
       "Resource": "*"
      }
   ]
})
}

# ---------- Redshift Cluster ---------- #

# Create the Redshift Cluster
resource "aws_redshift_cluster" "redshift-cluster" {
  depends_on = [
    aws_vpc.redshift-vpc,
    aws_redshift_subnet_group.redshift-subnet-group,
    aws_iam_role.redshift-role
  ]

  cluster_identifier = var.redshift_cluster_identifier
  database_name      = var.redshift_database_name
  master_username    = var.redshift_admin_username
  master_password    = var.redshift_admin_password
  node_type          = var.redshift_node_type
  cluster_type       = var.redshift_cluster_type
  number_of_nodes    = var.redshift_number_of_nodes

  iam_roles = [aws_iam_role.redshift-role.arn]

  cluster_subnet_group_name = aws_redshift_subnet_group.redshift-subnet-group.id
  
  skip_final_snapshot = true

  tags = {
    Name        = "redshift-cluster"
    Environment = var.app_environment
  }
}