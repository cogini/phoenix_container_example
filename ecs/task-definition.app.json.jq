{
  "family": env.FAMILY,
  "taskRoleArn": env.TASK_ROLE_ARN,
  "executionRoleArn": env.EXECUTION_ROLE_ARN,
  "networkMode": "awsvpc",
  "cpu": (env.APP_CPU // "256"),
  "memory": (env.APP_RAM // "512"),
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "runtimePlatform": {
    "cpuArchitecture": (env.ARCH // "X86_64"),
  },
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
          "value": env.GIT_SHA_SHORT
        },
        {
          "name": "APPSIGNAL_APP_NAME",
          "value": env.SERVICE
        },
        {
          "name": "APPSIGNAL_OTP_APP",
          "value": "phoenix_container_example"
        },
        {
          "name": "BUGSNAG_APP_VERSION",
          "value": env.GIT_SHA_SHORT
        },
        {
          "name": "COMPONENT",
          "value": env.COMP
        },
        {
          "name": "ENV",
          "value": env.ENV
        },
        {
          "name": "GIT_AUTHOR",
          "value": env.GIT_AUTHOR
        },
        {
          "name": "GIT_SHA",
          "value": env.GIT_SHA
        },
        {
          "name": "GIT_HEAD_REF",
          "value": env.GIT_HEAD_REF
        },
        {
          "name": "LIBCLUSTER_DEBUG",
          "value": "true"
        },
        {
          "name": "LIBCLUSTER_STRATEGY",
          "value": "ecs"
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
          "value": "aws.log.group.names=/ecs/\(env.SERVICE),service.namespace=ai,service.version=\(env.BUILD_NUM),deployment.environment=\(env.ENV)"
        },
        {
          "name": "OTEL_SERVICE_NAME",
          "value": env.SERVICE
        },
        {
          "name": "ROLES",
          "value": env.ROLES
        }
      ],
      "essential": true,
      "healthCheck": {
        "command": ["CMD", "/app/bin/prod", "eval", "PhoenixContainerExample.Health.basic()"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 2
      },
      "image": env.IMAGE,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-create-group": "true",
          "awslogs-group": env.AWSLOGS_GROUP,
          "awslogs-region": env.AWSLOGS_REGION,
          "awslogs-stream-prefix": env.AWSLOGS_STREAM_PREFIX
        }
      },
      "name": env.CONTAINER_NAME,
      "portMappings": [
        {
          "appProtocol": (env.APP_PROTOCOL // "http"),
          "containerPort": ((env.APP_PORT // "4000") | tonumber),
          "hostPort": ((env.APP_PORT // "4000") | tonumber),
          "name": "web"
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
      "image": env.IMAGE_OTEL,
      "cpu": 0,
      "environment": [
        {
          "name": "AWS_REGION",
          "value": env.AWSLOGS_REGION
        },
        {
          "name": "COMPONENT",
          "value": env.COMP
        }
      ],
      "secrets": [
        {
          "name": "PROMETHEUS_ENDPOINT",
          "valueFrom": "arn:aws:ssm:\(env.AWS_REGION):\(env.AWS_ACCOUNT_ID):parameter/amtelco/ai/\(env.ENV)/prometheus_endpoint"
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
          "awslogs-group": "/ecs/aws-otel-collector",
          "awslogs-region": env.AWSLOGS_REGION,
          "awslogs-stream-prefix": env.AWSLOGS_STREAM_PREFIX
        }
      }
    }
  ]
}
