#!/bin/bash
source /etc/profile

cd /mnt/aps/base_service/monitoring/prometheus-grafana/

helm install --tls \
        --name prometheus \
        --namespace monitoring \
        -f prom-settings.yaml \
        -f prom-alertsmanager.yaml \
        -f prom-alertrules.yaml \
        -f prom-alertstemplate.yaml \
        --set-file extraScrapeConfigs=extraScrapeConfigs.yaml \
        prometheus
