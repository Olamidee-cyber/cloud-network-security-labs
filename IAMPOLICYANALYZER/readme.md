# IAM Guardian 

**A Python + Boto3 CLI tool to detect over-permissive IAM policies in AWS.**

This script scans all IAM users and checks for attached policies (both managed and inline) that include dangerous wildcards like `Action: *` or `Resource: *`. It flags these policies to help enforce least-privilege access — a core AWS security principle.

---

## Features

- Lists all IAM users
- Lists attached managed and inline policies
- Fetches and scans policy documents
- Flags wildcard permissions (`Action: *`, `Resource: *`)
- Clean CLI output for security auditing

---

## 💻 Usage

1. **Configure AWS CLI credentials**  
   Make sure you’ve set up a user with proper permissions:
   ```bash
   aws configure
