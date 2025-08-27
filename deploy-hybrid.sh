#!/bin/bash

# Hybrid AWS Deployment: EC2 (Ollama GPU) + ECS (Services)
set -e

echo "🚀 Deploying Hybrid RAG System: EC2 GPU + ECS Services"

# Configuration
REGION="us-east-1"
CLUSTER_NAME="rag-cluster"
SERVICE_NAME="rag-service"
EC2_INSTANCE_TYPE="g5.xlarge"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_CIDR="10.0.2.0/24"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Step 1: Create VPC and Networking${NC}"

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --query 'Vpc.VpcId' \
  --output text)

echo "Created VPC: $VPC_ID"

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

# Create public subnet
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --query 'Subnet.SubnetId' \
  --output text)

# Create private subnet
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --query 'Subnet.SubnetId' \
  --output text)

# Create route table for public subnet
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table \
  --subnet-id $PUBLIC_SUBNET_ID \
  --route-table-id $ROUTE_TABLE_ID

echo -e "${GREEN}Step 2: Create Security Groups${NC}"

# Security group for EC2 (GPU instance)
EC2_SG_ID=$(aws ec2 create-security-group \
  --group-name rag-ec2-sg \
  --description "Security group for RAG EC2 GPU instance" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow SSH from anywhere (for demo - restrict in production)
aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Allow Ollama API from ECS
aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 11434 \
  --source-group $EC2_SG_ID

# Security group for ECS
ECS_SG_ID=$(aws ec2 create-security-group \
  --group-name rag-ecs-sg \
  --description "Security group for RAG ECS services" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow HTTP from ALB
aws ec2 authorize-security-group-ingress \
  --group-id $ECS_SG_ID \
  --protocol tcp \
  --port 8000 \
  --cidr 0.0.0.0/0

echo -e "${GREEN}Step 3: Create ECS Cluster${NC}"

# Create ECS cluster
aws ecs create-cluster \
  --cluster-name $CLUSTER_NAME \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1

echo -e "${GREEN}Step 4: Launch EC2 GPU Instance${NC}"

# Get latest Ubuntu AMI
AMI_ID=$(aws ssm get-parameters \
  --names /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id \
  --query 'Parameters[0].Value' \
  --output text)

# Create key pair (if doesn't exist)
KEY_NAME="rag-key"
aws ec2 create-key-pair \
  --key-name $KEY_NAME \
  --query 'KeyMaterial' \
  --output text > $KEY_NAME.pem

chmod 400 $KEY_NAME.pem

# Launch EC2 instance
EC2_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $EC2_INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $EC2_SG_ID \
  --subnet-id $PRIVATE_SUBNET_ID \
  --iam-instance-profile Name=EC2OllamaRole \
  --user-data file://ec2-userdata.sh \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Launched EC2 instance: $EC2_INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for EC2 instance to be ready..."
aws ec2 wait instance-running --instance-ids $EC2_INSTANCE_ID

# Get private IP
EC2_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $EC2_INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo "EC2 Private IP: $EC2_PRIVATE_IP"

echo -e "${GREEN}Step 5: Build and Push Docker Image${NC}"

# Create ECR repository
aws ecr create-repository \
  --repository-name rag-api \
  --region $REGION

# Get ECR login token
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build and push image
docker build -t rag-api .
docker tag rag-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/rag-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/rag-api:latest

echo -e "${GREEN}Step 6: Deploy ECS Service${NC}"

# Update task definition with actual values
sed -i "s/YOUR_ACCOUNT/$AWS_ACCOUNT_ID/g" ecs-task-definition.json
sed -i "s/YOUR_REGION/$REGION/g" ecs-task-definition.json
sed -i "s/YOUR_EC2_PRIVATE_IP/$EC2_PRIVATE_IP/g" ecs-task-definition.json

# Register task definition
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definition.json

# Create service
aws ecs create-service \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --task-definition rag-system:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_ID],securityGroups=[$ECS_SG_ID],assignPublicIp=ENABLED}"

echo -e "${GREEN}✅ Hybrid deployment complete!${NC}"
echo -e "${YELLOW}EC2 GPU Instance: $EC2_INSTANCE_ID${NC}"
echo -e "${YELLOW}EC2 Private IP: $EC2_PRIVATE_IP${NC}"
echo -e "${YELLOW}ECS Cluster: $CLUSTER_NAME${NC}"
echo -e "${YELLOW}ECS Service: $SERVICE_NAME${NC}"
echo -e "${YELLOW}Key file: $KEY_NAME.pem${NC}"


