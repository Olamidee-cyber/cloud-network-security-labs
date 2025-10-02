## Serverless Todo API (Terraform + AWS)

This lab demonstrates a fully serverless CRUD API using **Terraform** and AWS managed services.

### 🏗️ Stack
- **API Gateway (HTTP API)** → routes requests
- **Lambda Functions** → backend logic
  - `put_item.py` → create new todo
  - `get_item.py` → read todo by ID
  - `update_item.py` → update existing todo
  - `delete_item.py` → delete todo by ID
  - `handler.py` → basic health check
- **DynamoDB** → stores todo items (primary key: `id`)

---

### 🚀 Deploy
```bash
terraform init
terraform apply -auto-approve
