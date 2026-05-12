#!/bin/bash

dnf update -y
dnf install -y docker aws-cli python3 cronie
systemctl start docker
systemctl enable docker
systemctl start crond
systemctl enable crond

docker pull igior/weather-app:latest
docker run -d \
  --name weather-app \
  --restart always \
  -p 8080:8080 \
  igior/weather-app:latest

echo "Worker setup complete"