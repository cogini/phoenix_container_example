#!/usr/bin/env bash

set -euo pipefail

# Configure AWS CLI profile based SAML response
#
# First log in via the browser, using Chrome dev tools to log the request.
# Copy the SAML response (a big blob of base64) from the SAMLResponse HTTP
# header and put it in the file samlresponse.log.

IN_FILE="samlresponse.log"

# Staging AWS account
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-086708630682}"
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME:-ADFS-Vendor}"
SAML_PROVIDER="arn:aws:iam::${AWS_ACCOUNT_ID}:saml-provider/ADFS"
AWS_PROFILE="${AWS_PROFILE:-amtelco-test}"
AWS_REGION="${AWS_REGION:-us-east-2}"

OUT_FILE="$(mktemp -t saml)-assumed-role.json"
# Clean up: Remove the temporary file when done
# The trap command ensures cleanup even if the script exits unexpectedly.
trap 'rm -f "$OUT_FILE"' EXIT

aws sts assume-role-with-saml --role-arn "$ROLE_ARN" --principal-arn "$SAML_PROVIDER" --saml-assertion "file://${IN_FILE}" > "$OUT_FILE"
cat "$OUT_FILE"

aws configure set region "$AWS_REGION" --profile "$AWS_PROFILE"
aws configure set aws_access_key_id "$(cat "$OUT_FILE" | jq -r '.Credentials.AccessKeyId')" --profile "${AWS_PROFILE}"
aws configure set aws_secret_access_key "$(cat "$OUT_FILE" | jq -r '.Credentials.SecretAccessKey')" --profile "${AWS_PROFILE}"
aws configure set aws_session_token "$(cat "$OUT_FILE" | jq -r '.Credentials.SessionToken')" --profile "${AWS_PROFILE}"
aws configure set aws_session_expiration "$(cat "$OUT_FILE" | jq -r '.Credentials.Expiration')" --profile "${AWS_PROFILE}"
