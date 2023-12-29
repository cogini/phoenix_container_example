{
    "family": "foo-worker",
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
                    "value": "aws.log.group.names=/ecs/foo-worker"
                },
                {
                    "name": "OTEL_SERVICE_NAME",
                    "value": "foo-worker"
                },
                {
                    "name": "ROLES",
                    "value": "worker"
                }
            ],
            "essential": true,
            "image": "<IMAGE1_NAME>",
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "/ecs/foo-worker",
                    "awslogs-region": env.AWSLOGS_REGION,
                    "awslogs-stream-prefix": "foo-worker"
                }
            },
            "mountPoints": [],
            "name": "foo-worker",
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
                    "name": "DATABASE_URL",
                    "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/\(env.AWS_PS_PREFIX)/app/db/url"
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
                    "awslogs-stream-prefix": "foo-worker"
                }
            }
        }
    ]
}
