# Docker registry for internal images, e.g. 123.dkr.ecr.ap-northeast-1.amazonaws.com/
# If blank, docker.io will be used. If specified, should have a trailing slash.
ARG REGISTRY=""
# Registry for public images such as debian, alpine, or postgres.
ARG PUBLIC_REGISTRY="public.ecr.aws/"

# Public images may be mirrored into the private registry, with e.g. Skopeo
# ARG PUBLIC_REGISTRY=$REGISTRY

ARG AWS_REGION=us-east-1

ARG BASE_IMAGE_NAME=${PUBLIC_REGISTRY}aws-observability/aws-otel-collector
ARG BASE_IMAGE_TAG=latest

FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}
    ARG AWS_REGION

    ENV AWS_REGION=${AWS_REGION}

    COPY otel/aws-collector-config.yml /etc/otel-collector-config.yml
    COPY otel/extraconfig.tx[t] /opt/aws/aws-otel-collector/etc/extracfg.txt

    CMD ["--config=/etc/otel-collector-config.yml"]
    # CMD ["--config=/etc/ecs/ecs-default-config.yaml"]
