#!/usr/bin/env python

# Generate commands to set values in AWS SSM Parameter Store from a CSV file

# CSV format:
#   data_type: 'String' or 'SecureString'
#   name: SSM key
#   env: OS environment var name
#   value: value

# Example:
#   SecureString,db/url,DATABASE_URL,ecto://postgres:postgres@app-db.foo.internal/phoenix_container_example_dev
#   SecureString,release_cookie,RELEASE_COOKIE,lG5ehr1hQvbUOgkDWTQVWoItj1toyjss0qL_bbSNS67rKY0kpDno9Q==
#   SecureString,endpoint/secret_key_base,SECRET_KEY_BASE,lbMvIWnyI+ZMpA+FcN4HW2iUozEYgaOQcuQZ4yBYevI9QiOBFp0Jtj5FT96Rq3+T
#   String,endpoint/host,PHX_HOST,example.com

# SECRET_KEY_BASE: mix phx.gen.secret
# RELEASE_COOKIE: Base.url_encode64(:crypto.strong_rand_bytes(40))
# LIVE_VIEW_SIGNING_SALT: mix phx.gen.secret 32
# MQ_PASSWORD: mix phx.gen.secret 32
# AUTH_KEY:
#   ssh-keygen -N '' -t rsa -b 4096 -m PEM -f jwtRS256.key
#   openssl rsa -in jwtRS256.key -pubout -outform PEM -out jwtRS256.key.pub

# Self-signed certificate for Phoenix, HTTPS_CERT and HTTPS_KEY:
#   mix phx.gen.cert

# aws ssm get-parameters-by-path --path /cogini/foo/dev/app --recursive --with-decryption --no-paginate --region $AWS_REGION --query "Parameters[].{name:Name,valueFrom:Name}" --output json

import csv

import argparse

parser = argparse.ArgumentParser(description='Generate commands to set values in AWS SSM Parameter Store from a CSV file')
parser.add_argument('-p', '--prefix', dest='prefix', help='SSM parameter name prefix, e.g., /cogini/foo/dev/app/', required=True)
parser.add_argument('-i', '--infile', dest='infile', help='Input CSV file', default='params.csv')

args = parser.parse_args()
prefix = args.prefix
if not prefix.endswith('/'):
    prefix = prefix + '/'

with open(args.infile) as csvfile:
    reader = csv.reader(csvfile)
    for row in reader:
        data_type = row[0]
        name = row[1]
        env = row[2]
        value = row[3]
        print("aws ssm put-parameter --type %s --name '%s%s' --cli-input-json '{\"Value\": \"%s\"}' --overwrite" % (data_type, prefix, name, value))
