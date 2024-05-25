#!/bin/bash
source /etc/profile

cd /mnt/aps/base_service/monitoring/
pgusername=stolon
helm install --name postgres-exporter --set config.datasource.user=$pgusername postgres-exporter --namespace monitoring
