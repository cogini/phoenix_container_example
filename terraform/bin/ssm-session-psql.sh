#!/usr/bin/env bash

psql -h localhost -p 25432 -U postgres "${DB_NAME}"
