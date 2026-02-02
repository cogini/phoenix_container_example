#!/usr/bin/env bash

# Connect to remote PostgreSQL database via SSM session tunnel

psql -h localhost -p "${RDS_LOCAL_PORT:-25432}" -U postgres "${DB_NAME}"
