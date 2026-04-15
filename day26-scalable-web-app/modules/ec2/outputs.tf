output "launch_template_id" {
    value = aws_launch_template.web.id
    description = "ID of the launch template for the web servers"
}

output "launch_template_version" {
    value = aws_launch_template.web.latest_version
    description = "Latest version of the launch template for the web servers"
}

output "security_group_id" {
    value = aws_security_group.instancesg.id
    description = "ID of the security group for the web servers"
}