# Docker registry for our internal images, e.g. 123.dkr.ecr.us-east-1.amazonaws.com/
# If blank, docker.io will be used. If specified, should have a trailing slash.
ARG REGISTRY=""

# Registry for public images, e.g. debian, alpine, or postgres.
# Public images may be mirrored into the private registry, with e.g. Skopeo
ARG PUBLIC_REGISTRY=$REGISTRY

# https://www.npmjs.com/package/newman-reporter-junitfull

FROM ${PUBLIC_REGISTRY}postman/newman
RUN set -exu && \
    npm install -g newman-reporter-html && \
    npm install -g newman-reporter-json-summary && \
    npm install -g get-graphql-schema && \
    npm install -g newman-reporter-junitfull
