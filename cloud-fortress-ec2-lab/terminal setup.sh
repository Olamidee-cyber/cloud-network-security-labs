#!/bin/bash
sudo yum update -y
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd
echo " Hello from Cloud Fortress EC2 Web Server!" | sudo tee /var/www/html/index.html
