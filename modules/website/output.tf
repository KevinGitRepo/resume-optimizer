# Output to display the private IP addresses of all created EC2 instances
# The [*] syntax allows for multiple instances if count or for_each is used
output "website_url" {
    description = "Full URL of hosted website"
    value = "http://${aws_instance.web_server.public_dns}"
}
