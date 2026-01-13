# Task 2: Database Infrastructure Setup - Manual Guide

This guide walks you through setting up RDS PostgreSQL, Secrets Manager, and initializing the database schema using the AWS Console.

---

## Prerequisites

- Task 1 completed (VPC, subnets, security groups, IAM roles documented)
- Have your `docs/resource-inventory.md` file open for reference
- AWS Console access

---

## Step 1: Create RDS Subnet Group

An RDS subnet group defines which subnets your database can be deployed in.

### AWS Console Steps:

1. Go to **RDS Console** → **Subnet groups** (left sidebar)
2. Click **Create DB subnet group**
3. Configure:
   - **Name**: `task-management-db-subnet-group`
   - **Description**: `Subnet group for Task Management API database`
   - **VPC**: Select your VPC (from resource-inventory.md)
4. **Add subnets**:
   - **Availability Zones**: Select `us-east-1a` and `us-east-1b`
   - **Subnets**: Select your **Private Subnet 1** and **Private Subnet 2**
   - ⚠️ Make sure you select PRIVATE subnets, not public ones!
5. Click **Create**

### Verify:
- Subnet group status should be "Complete"
- Should show 2 subnets in 2 availability zones

### Document:
Add to `docs/resource-inventory.md` under "RDS Subnet Group":
```
Subnet Group Name: task-management-db-subnet-group
Subnets: [your private subnet IDs]
```

---

## Step 2: Create Secrets in AWS Secrets Manager

We'll create two secrets: one for database credentials and one for JWT signing.

### 2A: Create RDS Credentials Secret

1. Go to **Secrets Manager Console** → **Secrets** → **Store a new secret**
2. **Secret type**: Select **Credentials for Amazon RDS database**
3. Configure credentials:
   - **User name**: `dbadmin`
   - **Password**: Click **Generate random password** (or create your own strong password)
   - ⚠️ **IMPORTANT**: Copy this password somewhere safe temporarily!
4. **Database**: Leave as "Select a database" (we'll create RDS next)
5. Click **Next**
6. **Secret name**: `rds-credentials`
7. **Description**: `Database credentials for Task Management API`
8. Click **Next**
9. **Automatic rotation**: Leave disabled for now
10. Click **Next** → **Store**

### Document the Secret ARN:
After creation, click on the secret name and copy the **Secret ARN**. Add to `docs/resource-inventory.md`:
```
Secret Name: rds-credentials
ARN: arn:aws:secretsmanager:us-east-1:XXXXX:secret:rds-credentials-XXXXX
```

### 2B: Create JWT Secret

1. Go to **Secrets Manager Console** → **Store a new secret**
2. **Secret type**: Select **Other type of secret**
3. **Key/value pairs**:
   - Click **Plaintext** tab
   - Paste this JSON (generate a random 256-bit key):
   ```json
   {
     "secret": "your-super-secret-jwt-key-change-this-to-random-256-bit-string",
     "expiration": "3600"
   }
   ```
   - 💡 **Tip**: Generate a secure random key using: `openssl rand -base64 32` or use an online generator
4. Click **Next**
5. **Secret name**: `jwt-secret`
6. **Description**: `JWT signing key for Task Management API`
7. Click **Next** → **Next** → **Store**

### Document the Secret ARN:
Add to `docs/resource-inventory.md`:
```
Secret Name: jwt-secret
ARN: arn:aws:secretsmanager:us-east-1:XXXXX:secret:jwt-secret-XXXXX
```

---

## Step 3: Create RDS PostgreSQL Instance

Now we'll create the actual database.

### AWS Console Steps:

1. Go to **RDS Console** → **Databases** → **Create database**

2. **Choose a database creation method**: 
   - Select **Standard create**

3. **Engine options**:
   - **Engine type**: PostgreSQL
   - **Engine version**: PostgreSQL 15.x (latest 15.x version)

4. **Templates**:
   - Select **Free tier** (if eligible) OR **Dev/Test**

5. **Settings**:
   - **DB instance identifier**: `task-management-db`
   - **Master username**: `dbadmin` (must match what you put in Secrets Manager!)
   - **Master password**: Use the SAME password you generated in Secrets Manager
   - **Confirm password**: Re-enter the password

6. **Instance configuration**:
   - **DB instance class**: `db.t3.micro` (free tier eligible)
   - If you don't see t3.micro, select **Burstable classes** and choose `db.t3.micro`

7. **Storage**:
   - **Storage type**: General Purpose SSD (gp2)
   - **Allocated storage**: `20` GB
   - **Storage autoscaling**: Uncheck (for learning/cost control)

8. **Connectivity**:
   - **Virtual private cloud (VPC)**: Select your VPC
   - **DB subnet group**: Select `task-management-db-subnet-group`
   - **Public access**: **No** (very important!)
   - **VPC security group**: 
     - Choose **Choose existing**
     - Select `task-mgmt-rds-sg` (the RDS security group you created in Task 1)
     - Remove the default security group
   - **Availability Zone**: No preference
   - **Database port**: `5432` (default)

9. **Database authentication**:
   - Select **Password authentication**

10. **Additional configuration** (expand this section):
    - **Initial database name**: `taskmanagement`
    - ⚠️ **IMPORTANT**: Don't skip this! If you don't set it, you'll have to create the database manually later
    - **DB parameter group**: default.postgres15
    - **Backup**:
      - **Enable automated backups**: Yes
      - **Backup retention period**: 7 days
      - **Backup window**: No preference
    - **Encryption**: 
      - **Enable encryption**: Yes (default)
    - **Maintenance**:
      - **Enable auto minor version upgrade**: Yes
    - **Deletion protection**: 
      - **Uncheck** for learning (easier to delete later)
      - ⚠️ In production, you'd enable this!

11. **Estimated monthly costs**: Review (should be ~$15-20/month for db.t3.micro)

12. Click **Create database**

### Wait for Creation:
- This takes 5-10 minutes
- Status will change from "Creating" → "Backing up" → "Available"
- ☕ Good time for a coffee break!

### After Database is Available:

1. Click on your database instance `task-management-db`
2. In the **Connectivity & security** tab, find:
   - **Endpoint**: Something like `task-management-db.xxxxx.us-east-1.rds.amazonaws.com`
   - **Port**: `5432`
3. **Copy the endpoint** - you'll need it!

### Document:
Add to `docs/resource-inventory.md`:
```
DB Instance ID: task-management-db
Endpoint: task-management-db.xxxxx.us-east-1.rds.amazonaws.com
Port: 5432
Engine: PostgreSQL 15.x
Instance Class: db.t3.micro
Storage: 20 GB GP2
Database Name: taskmanagement
Master Username: dbadmin
```

---

## Step 4: Update Secrets with RDS Endpoint

Now that we have the RDS endpoint, let's update the secret.

### Update rds-credentials Secret:

1. Go to **Secrets Manager Console** → **Secrets**
2. Click on `rds-credentials`
3. Click **Retrieve secret value**
4. Click **Edit**
5. Switch to **Plaintext** tab
6. Update the JSON to include the endpoint:
   ```json
   {
     "username": "dbadmin",
     "password": "your-password-here",
     "host": "task-management-db.xxxxx.us-east-1.rds.amazonaws.com",
     "port": 5432,
     "dbname": "taskmanagement"
   }
   ```
7. Replace `your-password-here` with your actual password
8. Replace the `host` value with your actual RDS endpoint
9. Click **Save**

### Verify:
- Click **Retrieve secret value** again
- Confirm all fields are correct

---

## Step 5: Initialize Database Schema

Now we need to connect to the database and create the tables.

### Option A: Using psql (Recommended)

If you have PostgreSQL client installed locally:

1. **Install psql** (if not already installed):
   - **Mac**: `brew install postgresql`
   - **Windows**: Download from postgresql.org
   - **Linux**: `sudo apt-get install postgresql-client`

2. **Connect to RDS**:
   ```bash
   psql -h task-management-db.xxxxx.us-east-1.rds.amazonaws.com \
        -U dbadmin \
        -d taskmanagement \
        -p 5432
   ```
   - Enter your password when prompted

3. **Run the schema SQL** (see SQL script below)

### Option B: Using AWS Systems Manager Session Manager

If you can't connect directly (firewall/network issues):

1. Launch an EC2 instance in the same VPC (t2.micro, Amazon Linux 2)
2. Install PostgreSQL client: `sudo yum install postgresql15`
3. Connect from the EC2 instance to RDS
4. Run the schema SQL

### Option C: Using a Database Client (DBeaver, pgAdmin, etc.)

1. Download and install DBeaver or pgAdmin
2. Create a new connection:
   - **Host**: Your RDS endpoint
   - **Port**: 5432
   - **Database**: taskmanagement
   - **Username**: dbadmin
   - **Password**: Your password
3. Run the schema SQL

---

## Database Schema SQL

Once connected, run this SQL to create the tables:

```sql
-- Create users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for users table
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- Create tasks table
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    priority VARCHAR(20) DEFAULT 'medium',
    due_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for tasks table
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);

-- Verify tables were created
\dt

-- Verify indexes were created
\di

-- Check table structure
\d users
\d tasks
```

### Verify Schema Creation:

After running the SQL, verify:
```sql
-- Should show 2 tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public';

-- Should show 5 indexes
SELECT indexname FROM pg_indexes 
WHERE schemaname = 'public';
```

Expected output:
- Tables: `users`, `tasks`
- Indexes: `users_pkey`, `idx_users_username`, `idx_users_email`, `tasks_pkey`, `idx_tasks_user_id`, `idx_tasks_status`, `idx_tasks_due_date`

---

## Step 6: Test Database Connection

Let's verify everything works:

```sql
-- Insert a test user
INSERT INTO users (username, email, password_hash) 
VALUES ('testuser', 'test@example.com', 'test_hash_123');

-- Verify insertion
SELECT * FROM users;

-- Insert a test task
INSERT INTO tasks (user_id, title, description, status, priority) 
VALUES (1, 'Test Task', 'This is a test', 'pending', 'high');

-- Verify insertion
SELECT * FROM tasks;

-- Clean up test data
DELETE FROM tasks WHERE id = 1;
DELETE FROM users WHERE id = 1;

-- Verify cleanup
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM tasks;
```

Both counts should be 0.

---

## Troubleshooting

### Can't connect to RDS from local machine?

**Problem**: Connection timeout or refused

**Solutions**:
1. **Check security group**: Make sure your RDS security group allows inbound on port 5432
2. **Temporary fix for testing**: Add your IP to the RDS security group:
   - Go to EC2 → Security Groups → `task-mgmt-rds-sg`
   - Add inbound rule: PostgreSQL (5432) from your IP address
   - ⚠️ Remove this rule after testing!
3. **Use EC2 bastion**: Launch an EC2 instance in the same VPC to connect

### Wrong password?

**Problem**: Authentication failed

**Solution**: 
- Double-check the password in Secrets Manager matches what you used when creating RDS
- You can reset the master password in RDS Console → Modify

### Database doesn't exist?

**Problem**: `database "taskmanagement" does not exist`

**Solution**:
- Connect to the default `postgres` database first:
  ```bash
  psql -h your-endpoint -U dbadmin -d postgres
  ```
- Create the database:
  ```sql
  CREATE DATABASE taskmanagement;
  ```
- Reconnect to `taskmanagement` and run the schema SQL

---

## Verification Checklist

Before moving to Task 3, verify:

- [ ] RDS subnet group created with 2 private subnets
- [ ] `rds-credentials` secret created with all fields (username, password, host, port, dbname)
- [ ] `jwt-secret` secret created with secret key and expiration
- [ ] RDS PostgreSQL instance is "Available"
- [ ] RDS endpoint documented in resource-inventory.md
- [ ] Can connect to database (from EC2 or locally)
- [ ] `users` table created with 2 indexes
- [ ] `tasks` table created with 3 indexes
- [ ] Test insert/select/delete works
- [ ] All resource ARNs documented

---

## Cost Reminder

**Current monthly cost**: ~$15-20 for RDS db.t3.micro

The database is now running 24/7. Remember to delete it when you're done learning!

---

## Next Steps

Once everything is verified, you're ready for **Task 3: Container Registry Setup (ECR)**.

Great job! 🎉 The database infrastructure is complete!
