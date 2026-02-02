#!/usr/bin/env bash

# Use AWS SSM Session Manager port forwarding to RDS
# https://www.element7.io/2022/12/aws-ssm-session-manager-port-forwarding-to-rds-without-ssh/ 
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started.html
# https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-macos-overview.html
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/session-manager-plugin.pkg" -o "session-manager-plugin.pkg"

echo aws ssm start-session --region "$AWS_REGION" \
    --target "$DEVOPS_INSTANCE" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters host="${RDS_HOST},portNumber=${RDS_PORT:-5432},localPortNumber=${RDS_LOCAL_PORT:-25432}"
