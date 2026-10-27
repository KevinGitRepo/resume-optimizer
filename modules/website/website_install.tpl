#!/bin/bash
yum update -y
yum install -y httpd aws-cli
service httpd restart
systemctl enable httpd
systemctl start httpd

aws s3 sync s3://final-project-shared-bucket/website/ /var/www/html/

API_URL=$(aws ssm get-parameter --name "/resume/api_gateway_url" --query "Parameter.Value" --output text)
sed -i "s|{{API_GATEWAY_URL}}|$API_URL|g" /var/www/html/script.js

chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html