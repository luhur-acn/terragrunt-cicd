# Target Groups Inventory Configuration
# Comment out all blocks to execute GitOps destroy

inputs = {
  "web-tg" = {
    name        = "web-dev-v2-tg"
    port        = 80
    protocol    = "HTTP"
    vpc_id      = "vpc-dev-v2"
    target_type = "instance"

    health_check = {
      enabled             = true
      interval            = 30
      path                = "/"
      port                = "traffic-port"
      protocol            = "HTTP"
      timeout             = 5
      healthy_threshold   = 3
      unhealthy_threshold = 3
      matcher             = "200"
    }

    attachments = [
      {
        target_id = "web-app-v2-01"
        port      = 80
      },
      {
        target_id = "web-app-v2-02"
        port      = 80
      }
    ]
  }
}
