variable "instance_type" {}
variable "ami_id" {}
variable "public_subnet_id" {}
variable "ec2_security_group_id" {}
variable "enable_public_ip_address" {}
variable "key_name" {} 
variable "iam_instance_profile" {}
variable "is_leader" {
  default = false
}



output "ec2_instance_id" {
  value = aws_instance.ec2_instance.id
}


# Create ec2 instance
resource "aws_instance" "ec2_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.ec2_security_group_id]
  associate_public_ip_address = var.enable_public_ip_address
  key_name = var.key_name
  iam_instance_profile = var.iam_instance_profile

  user_data = var.is_leader ? local.leader_user_data : local.worker_user_data


  tags = {
    Name = "EC2 Deploy App Instance"
    Role = var.is_leader ? "leader" : "worker"
  }
}

locals {
  base_setup = <<-BASE
    #!/bin/bash
    dnf update -y
    dnf install -y docker aws-cli python3
    systemctl start docker
    systemctl enable docker

    docker pull igior/weather-app:latest
    docker run -d \
      --name weather-app \
      --restart always \
      -p 8080:8080 \
      igior/weather-app:latest
  BASE

  leader_user_data = <<-LEADER
    ${local.base_setup}

    # Fetch RDS credentials from Secrets Manager
    SECRET=$(aws secretsmanager get-secret-value \
      --secret-id rds/postgres/credentials \
      --region us-east-1 \
      --query SecretString \
      --output text)

    DB_HOST=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['host'])")
    DB_PORT=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['port'])")
    DB_NAME=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['dbname'])")
    DB_USER=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
    DB_PASS=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

    # Initialize the database tables
    docker run --rm \
      -e DB_HOST=$DB_HOST \
      -e DB_PORT=$DB_PORT \
      -e DB_NAME=$DB_NAME \
      -e DB_USER=$DB_USER \
      -e DB_PASS=$DB_PASS \
      igior/weather-app:latest \
      python3 -c "
    import psycopg2, os
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST'), port=os.getenv('DB_PORT'),
        dbname=os.getenv('DB_NAME'), user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASS'), sslmode='require'
    )
    with conn:
        with conn.cursor() as cur:
            cur.execute('''
                CREATE TABLE IF NOT EXISTS weather_readings (
                    id SERIAL PRIMARY KEY,
                    recorded_at TIMESTAMP NOT NULL,
                    temperature NUMERIC(5,2),
                    feels_like NUMERIC(5,2),
                    humidity INTEGER,
                    pressure NUMERIC(7,2),
                    wind_speed NUMERIC(5,2),
                    wind_direction INTEGER,
                    precipitation NUMERIC(5,2),
                    visibility NUMERIC(5,2),
                    description VARCHAR(100)
                )
            ''')
            cur.execute('''
                CREATE TABLE IF NOT EXISTS weather_hourly_stats (
                    hour_start TIMESTAMP PRIMARY KEY,
                    avg_temperature NUMERIC(5,2),
                    avg_feels_like NUMERIC(5,2),
                    avg_humidity NUMERIC(5,2),
                    avg_pressure NUMERIC(7,2),
                    avg_wind_speed NUMERIC(5,2),
                    avg_wind_direction NUMERIC(5,1),
                    total_precipitation NUMERIC(5,2),
                    avg_visibility NUMERIC(5,2),
                    reading_count INTEGER,
                    updated_at TIMESTAMP
                )
            ''')
    conn.close()
    print('Tables created successfully')
    "

    # Set up cron jobs on leader only
    echo "*/10 * * * * root docker run --rm \
      -e DB_HOST=$DB_HOST \
      -e DB_PORT=$DB_PORT \
      -e DB_NAME=$DB_NAME \
      -e DB_USER=$DB_USER \
      -e DB_PASS=$DB_PASS \
      igior/weather-app:latest \
      python3 weather-fetcher.py >> /var/log/weather-fetcher.log 2>&1" > /etc/cron.d/weather-fetcher

    echo "55 * * * * root docker run --rm \
      -e DB_HOST=$DB_HOST \
      -e DB_PORT=$DB_PORT \
      -e DB_NAME=$DB_NAME \
      -e DB_USER=$DB_USER \
      -e DB_PASS=$DB_PASS \
      igior/weather-app:latest \
      python3 weather-aggregator.py >> /var/log/weather-aggregator.log 2>&1" > /etc/cron.d/weather-aggregator

    chmod 644 /etc/cron.d/weather-fetcher
    chmod 644 /etc/cron.d/weather-aggregator
  LEADER

  worker_user_data = local.base_setup
}