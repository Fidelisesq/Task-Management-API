# Use existing hosted zone
data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

# A Record for API (ALB)
resource "aws_route53_record" "api" {
  zone_id = var.hosted_zone_id
  name    = "${var.api_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# A Record for Frontend (CloudFront)
resource "aws_route53_record" "frontend" {
  zone_id = var.hosted_zone_id
  name    = "${var.frontend_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}
