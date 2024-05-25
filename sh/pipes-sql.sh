#!/bin/bash

export PGPASSWORD=test

pg_host="pg-stolon-proxy.aps-os.svc.cluster.local"
psql -h ${pg_host} -p 5432 -U triceed -d datacanvas_aps -f /usr/local/aps/http_root/postgres/pipes.sql
