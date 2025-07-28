## S3 Breach Lab

#  AWS S3 Breach Lab (Week 1)

**Lab Goal:** Simulate a public misconfiguration on an S3 bucket, detect the breach, and patch it using IAM and CloudTrail.

---

##Lab Steps

### 1. Create S3 Bucket & Upload Secret File
- Bucket name: `s3-breach-lab-olamideadenuga`
- File uploaded: `secret.rtf`

### 2. Misconfigure Bucket Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::s3-breach-lab-olamideadenuga/*"
    }
  ]
}

