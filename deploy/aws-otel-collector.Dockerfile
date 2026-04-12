# Docker registry for internal images, e.g., 123.dkr.ecr.ap-northeast-1.amazonaws.com/
# If blank, docker.io will be used. If specified, should have a trailing slash.
ARG REGISTRY=""
# Registry for public images such as debian, alpine, or postgres.
# ARG PUBLIC_REGISTRY="public.ecr.aws/"
ARG PUBLIC_REGISTRY=""

# Public images may be mirrored into the private registry, with e.g. Skopeo
# ARG PUBLIC_REGISTRY=$REGISTRY

ARG AWS_REGION=us-east-1

# ARG BASE_IMAGE_TAG=latest
ARG BASE_IMAGE_TAG=v0.47.0

# FROM ${PUBLIC_REGISTRY}aws-observability/aws-otel-collector:${BASE_IMAGE_TAG}
FROM ${PUBLIC_REGISTRY}${AWS_OTEL_COLLECTOR_REPO_ORG:-amazon}/aws-otel-collector:${BASE_IMAGE_TAG}

ARG AWS_REGION

ENV AWS_REGION=${AWS_REGION}

COPY --link otel/aws-collector-config.yml /etc/otel-collector-config.yml
COPY --link otel/extraconfig.tx[t] /opt/aws/aws-otel-collector/etc/extracfg.txt

CMD ["--config=/etc/otel-collector-config.yml"]
# CMD ["--config=/etc/ecs/ecs-default-config.yaml"]
