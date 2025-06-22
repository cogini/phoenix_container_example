{
    "family": "foo-app",
    "taskRoleArn": env.TASK_ROLE_ARN,
    "executionRoleArn": env.EXECUTION_ROLE_ARN,
    "networkMode": "awsvpc",
    "cpu": "256",
    "memory": "512",
    "requiresCompatibilities": ["FARGATE"],
    "runtimePlatform": {"cpuArchitecture": "X86_64"},
    "containerDefinitions": [
        {
            "cpu": 0,
            "dependsOn": [
                {
                    "containerName": "aws-otel-collector",
                    "condition": "START"
                }
            ],
            "environment": [
                {
                    "name": "APP_REVISION",
                    "value": env.GITHUB_SHA_SHORT
                },
                {
                    "name": "APPSIGNAL_OTP_APP",
                    "value": "phoenix_container_example"
                },
                {
                    "name": "APPSIGNAL_APP_NAME",
                    "value": "phoenix_container_example"
                },
                {
                    "name": "BUGSNAG_APP_VERSION",
                    "value": env.GITHUB_SHA_SHORT
                },
                {
                    "name": "GITHUB_SHA",
                    "value": env.GITHUB_SHA
                },
                {
                    "name": "GITHUB_HEAD_REF",
                    "value": env.GITHUB_HEAD_REF
                },
                {
                    "name": "LIBCLUSTER_STRATEGY",
                    "value": "dns"
                },
                {
                    "name": "OTEL_EXPORTER_OTLP_ENDPOINT",
                    "value": "http://localhost:4317"
                },
                {
                    "name": "OTEL_EXPORTER_OTLP_PROTOCOL",
                    "value": "grpc"
                },
                {
                    "name": "OTEL_RESOURCE_ATTRIBUTES",
                    "value": "aws.log.group.names=/ecs/foo-app"
                },
                {
                    "name": "OTEL_SERVICE_NAME",
                    "value": "foo-app"
                },
                {
                    "name": "ROLES",
                    "value": "app"
                }
            ],
            "essential": true,
            "healthCheck": {
                "command": ["CMD", "/app/bin/prod", "eval", "PhoenixContainerExample.Health.basic()"],
                "interval": 5,
                "timeout": 2,
                "retries": 10,
                "startPeriod": 2
            },
            "image": "<IMAGE1_NAME>",
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "/ecs/foo-app",
                    "awslogs-region": env.AWSLOGS_REGION,
                    "awslogs-stream-prefix": "foo-app"
                }
            },
            "mountPoints": [],
            "name": "foo-app",
            "portMappings": [
                {
                    "appProtocol": "http",
                    "containerPort": 4000,
                    "hostPort": 4000
                }
            ],
            "readonlyRootFilesystem": false,
            "entryPoint": ["bin/start-docker"],
            "secrets": [
                {
                    "name": "APPSIGNAL_APP_ENV",
                    "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/\(env.AWS_PS_PREFIX)/app/appsignal_app_env"
                },
                {
                    "name": "APPSIGNAL_PUSH_API_KEY",
                    "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/\(env.AWS_PS_PREFIX)/app/appsignal_push_api_key"
                },
                {
                    "name": "DATABASE_URL",
                    "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/\(env.AWS_PS_PREFIX)/app/db/url"
                },
                {
                    "name": "HTTPS_CERT",
                    "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/\(env.AWS_PS_PREFIX)/app/endpoint/https_cert"
                },
                {
                    "name": "HTTPS_KEY",
                    "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/\(env.AWS_PS_PREFIX)/app/endpoint/https_key"
                },
                {
                    "name": "PHX_HOST",
                    "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/\(env.AWS_PS_PREFIX)/app/endpoint/host"
                },
                {
                    "name": "RELEASE_COOKIE",
                    "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/\(env.AWS_PS_PREFIX)/app/release_cookie"
                },
                {
                    "name": "SECRET_KEY_BASE",
                    "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/\(env.AWS_PS_PREFIX)/app/endpoint/secret_key_base"
                }
            ],
            "startTimeout": 30,
            "stopTimeout": 30
        },
        {
            "name": "aws-otel-collector",
            "image": "\(env.ECR_REGISTRY)/\(env.ECR_IMAGE_OWNER)aws-otel-collector",
            "cpu": 0,
            "environment": [
                {
                    "name": "AWS_REGION",
                    "value": env.AWSLOGS_REGION
                }
            ],
            "essential": true,
            "healthCheck": {
                "command": [ "/healthcheck" ],
                "interval": 5,
                "timeout": 6,
                "retries": 5,
                "startPeriod": 1
            },
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "/ecs/ecs-aws-otel-sidecar-collector",
                    "awslogs-region": env.AWSLOGS_REGION,
                    "awslogs-stream-prefix": "foo-app"
                }
            }
        }
    ]
}
