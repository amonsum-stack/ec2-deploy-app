# EC2 Deploy App

Deploys the Belgrade weather app on Docker containers running across EC2 instances, provisioned entirely with Terraform modules.

## Overview

The goal of this project was to explore Terraform modules and how they simplify resource management. All infrastructure is split into reusable modules — network, EC2, RDS, load balancer, security groups, CloudWatch, and SNS.

## Architecture

```
Internet
   │
   ▼
Load Balancer (public subnets)
   │
   ▼
EC2 Instances x3 (private subnets) - Bastion Host (public subnet, SSH only)
   │
   ▼
RDS Postgres (private subnets)
```

- **Load Balancer** — the only public entry point for app traffic
- **EC2 instances** — run the weather app in Docker, no public IPs
- **Bastion host** — SSH access to private instances, locked to operator IP
- **NAT Gateway** — allows EC2 instances to reach the internet (Docker pulls, Open-Meteo API) without public IPs
- **RDS Postgres** — stores weather readings, accessible from EC2 only

## How to Deploy

```bash
terraform init
terraform apply
```

After apply, Terraform outputs the bastion IP and load balancer DNS.

## Data Collection

Weather data is collected by cron jobs running on the leader EC2 instance:

- **Fetcher** — pulls current conditions from Open-Meteo every 10 minutes, writes to `weather_readings` table
- **Aggregator** — runs at :55 each hour, summarises the previous hour into `weather_hourly_stats` table

RDS credentials are stored in AWS Secrets Manager and injected into the cron jobs at boot via the leader's user data script.

## Monitoring

CloudWatch alarms monitor the RDS instance and send email notifications via SNS:

- High CPU utilization (> 90%)
- Low free storage (< 4GB)
- High connection count (> 48/60)
- Instance availability

> **Note:** CloudWatch log groups and metric filters are implemented in the codebase (`modules/cloudwatch_logs`) but disabled due to lab IAM restrictions (`logs:PutMetricFilter`, `logs:DeleteLogGroup` not permitted). The CloudWatch agent on the leader instance still ships logs <to be confirmed>. The module can be re-enabled on a full AWS account.

## SSH Access

```bash
eval $(ssh-agent -s)
ssh-add ~/.ssh/ec2-aws.pem
ssh -A -J ec2-user@<bastion_ip> ec2-user@<private_instance_ip>
```

## Potential Improvements

- **Auto Scaling Group** — replace fixed 3-instance count with an ASG for automatic scaling and self-healing
- **ECR instead of DockerHub** — store the image privately; EC2 instances already have IAM roles so no credentials would be needed
- **Prometheus + Grafana** — the app already exposes `/metrics` with custom gauges (temperature, humidity, wind speed, pressure, visibility); a dedicated monitoring instance running both tools in Docker would complete the observability stack
- **HTTPS** — add an ACM certificate and HTTPS listener to the load balancer

