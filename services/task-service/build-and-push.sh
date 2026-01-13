#!/bin/bash

# Build and Push Task Service to ECR
# This script builds the Docker image and pushes it to Amazon ECR

set -e

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="211125602758"
ECR_REPOSITORY="task-service"
IMAGE_TAG="v1.0.0"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"

echo "=========================================="
echo "Building Task Service Docker Image"
echo "=========================================="

# Build Docker image
echo "Building Docker image..."
docker build -t ${ECR_REPOSITORY}:${IMAGE_TAG} .

# Tag image for ECR
echo "Tagging image for ECR..."
docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_URI}:latest

echo "=========================================="
echo "Authenticating Docker to ECR"
echo "=========================================="

# Authenticate Docker to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

echo "=========================================="
echo "Pushing Image to ECR"
echo "=========================================="

# Push images to ECR
echo "Pushing ${ECR_URI}:${IMAGE_TAG}..."
docker push ${ECR_URI}:${IMAGE_TAG}

echo "Pushing ${ECR_URI}:latest..."
docker push ${ECR_URI}:latest

echo "=========================================="
echo "Build and Push Complete!"
echo "=========================================="
echo "Image URI: ${ECR_URI}:${IMAGE_TAG}"
echo ""
echo "Next steps:"
echo "1. Verify image in ECR console"
echo "2. Check vulnerability scan results"
echo "3. Use this image URI in ECS task definition"
