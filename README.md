# ECS Task Management API - Manual Implementation Project

A learning project for building a Task Management API on AWS ECS with manual AWS Console implementation.

## Project Overview

This project demonstrates:
- Container orchestration with AWS ECS Fargate
- Service discovery with AWS Cloud Map
- Load balancing with Application Load Balancer
- Auto-scaling based on CPU metrics
- Database integration with RDS PostgreSQL
- JWT authentication and authorization
- Secrets management with AWS Secrets Manager
- Monitoring and logging with CloudWatch

## Architecture

The system consists of two microservices:
- **Auth Service**: User authentication and JWT token management
- **Task Service**: CRUD operations for tasks

Both services run in ECS Fargate, fronted by an ALB, backed by RDS PostgreSQL.

## Project Structure

```
.
├── .kiro/specs/ecs-task-management-api/
│   ├── requirements.md           # Detailed requirements
│   ├── design.md                 # Architecture and design
│   ├── tasks.md                  # Implementation checklist
│   └── implementation-guide.md   # Step-by-step guide
├── docs/
│   └── resource-inventory.md     # Track all AWS resource IDs
├── scripts/
│   └── 01-foundation-setup.sh    # AWS CLI commands for Task 1
├── iam-policies/
│   ├── ecs-task-execution-trust-policy.json
│   ├── secrets-manager-policy.json
│   └── cloudwatch-logs-policy.json
└── README.md
```

## Getting Started

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Basic understanding of Docker, ECS, and AWS services

### Implementation Approach

This is a **manual learning project**. You have two options:

#### Option 1: AWS Console (Recommended for Learning)
Follow the step-by-step guide in `.kiro/specs/ecs-task-management-api/implementation-guide.md`

#### Option 2: AWS CLI
Use the scripts in the `scripts/` directory for faster setup:

```bash
# Task 1: Foundation Setup
bash scripts/01-foundation-setup.sh
```

### Task Checklist

Track your progress using `.kiro/specs/ecs-task-management-api/tasks.md`:

- [ ] Task 1: Foundation Setup (VPC, Security Groups, IAM Roles)
- [ ] Task 2: Database Infrastructure (RDS, Secrets Manager)
- [ ] Task 3: Container Registry Setup (ECR)
- [ ] Task 4: Build and Push Auth Service Container
- [ ] Task 5: Build and Push Task Service Container
- [ ] Task 6: ECS Cluster and Service Discovery Setup
- [ ] **⚠️ CRITICAL: Configure VPC Endpoints** (See `guides/vpc-endpoints-setup-guide.md`)
- [ ] Task 7: Deploy Auth Service to ECS
- [ ] Task 8: Deploy Task Service to ECS
- [ ] Task 9: Checkpoint - Verify Services Running
- [ ] Task 10: Application Load Balancer Configuration
- [ ] Task 11: Auto Scaling Configuration
- [ ] Task 12: Monitoring and Alarms Setup
- [ ] Task 13-16: End-to-End Testing
- [ ] Task 17: Load Testing and Auto Scaling Verification
- [ ] Task 18: Security Verification
- [ ] Task 19: Final System Validation
- [ ] Task 20: Documentation and Learning Review

## Resource Tracking

As you create AWS resources, document them in `docs/resource-inventory.md`. This is critical for:
- Referencing resource IDs in later tasks
- Troubleshooting issues
- Cost tracking
- Cleanup when done

## Estimated Time

- **Total Implementation**: 4-6 hours
- **Task 1 (Foundation Setup)**: 30-45 minutes

## Cost Considerations

Estimated monthly cost: **$64-99/month** (with VPC Endpoints) or **$70-105/month** (with NAT Gateway)

- ECS Fargate (4 tasks): ~$30
- RDS db.t3.micro: ~$15
- ALB: ~$20
- **VPC Endpoints (recommended)**: ~$29 OR **NAT Gateway**: ~$35
- CloudWatch Logs: ~$5

**Important**: Remember to clean up resources after learning to avoid ongoing charges!

## ⚠️ Critical: Network Configuration for Private Subnets

**Before deploying ECS services (Tasks 7-8), you MUST configure network access for private subnets.**

Your ECS tasks run in private subnets and need to access AWS services (Secrets Manager, ECR, S3, CloudWatch Logs). Choose one option:

### Option 1: VPC Endpoints (Recommended - Lower Cost)
- Create 5 VPC Endpoints: Secrets Manager, ECR API, ECR Docker, CloudWatch Logs, S3
- Cost: ~$29/month
- More secure (traffic stays in AWS network)
- **📄 Complete guide:** `guides/vpc-endpoints-setup-guide.md`

### Option 2: NAT Gateway
- Configure NAT Gateway in public subnet
- Update private subnet route table: `0.0.0.0/0 → NAT Gateway`
- Cost: ~$35/month
- Simpler setup if NAT Gateway already exists

**Without this configuration, ECS tasks will fail to start with:**
```
ResourceInitializationError: unable to pull secrets or registry auth
ResourceInitializationError: failed to validate logger args
```

**See `guides/vpc-endpoints-setup-guide.md` for detailed setup instructions.**

## Learning Objectives

By completing this project, you will understand:

1. **Container Orchestration**: How ECS manages containerized applications
2. **Service Discovery**: How services find and communicate with each other
3. **Load Balancing**: How ALB distributes traffic across multiple instances
4. **Auto Scaling**: How services scale based on demand
5. **Database Integration**: How to connect ECS services to RDS
6. **Security**: IAM roles, security groups, secrets management
7. **Monitoring**: CloudWatch logs, metrics, and alarms

## Next Steps

1. **Start with Task 1**: Run the commands in `scripts/01-foundation-setup.sh`
2. **Document Resources**: Fill in `docs/resource-inventory.md` as you create resources
3. **Follow the Guide**: Use `implementation-guide.md` for detailed instructions
4. **Test Thoroughly**: Complete all testing tasks (13-18)
5. **Review and Learn**: Document what you learned in Task 20

## Support

- Review the design document for architecture details
- Check the requirements document for acceptance criteria
- Refer to the implementation guide for step-by-step instructions
- Use AWS documentation for specific service details

## Cleanup

When you're done learning, follow these steps to avoid charges:

1. Delete ECS services
2. Delete ECS cluster
3. Delete ALB and target groups
4. Delete RDS instance (disable deletion protection first)
5. Delete ECR repositories
6. **Delete VPC Endpoints** (if created)
7. Delete CloudWatch log groups
8. Delete Secrets Manager secrets
9. Delete security groups
10. Delete IAM roles and policies
11. (Optional) Delete VPC if you created it for this project

---

**Happy Learning!** 🚀
