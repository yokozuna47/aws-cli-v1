output "site_url" {
  value = "http://${aws_lb.public.dns_name}"
}

output "internal_alb_dns" {
  value = aws_lb.internal.dns_name
}

output "db_host" {
  value = var.db_host
}
