# Build app
# Deploy using Alpine

ARG BASE_OS=alpine

# Specify versions of Erlang, Elixir, and base OS.
# Choose a combination supported by https://hub.docker.com/r/hexpm/elixir/tags

ARG ELIXIR_VER=1.18.3
ARG OTP_VER=27.3.4

# https://hub.docker.com/_/alpine
ARG BUILD_OS_VER=3.17.5
ARG PROD_OS_VER=3.17.5

# By default, packages come from the APK index for the base Alpine image.
# Package versions are consistent between builds, and we normally upgrade by
# upgrading the Alpine version.
ARG APK_UPDATE=":"
ARG APK_UPGRADE=":"

# If a vulnerability is fixed in packages but not yet released in an Alpine
# base image, then we can run update/upgrade as part of the build.
# ARG APK_UPDATE="apk update"
# ARG APK_UPGRADE="apk upgrade --update-cache -a"

# Docker registry for internal images, e.g. 123.dkr.ecr.ap-northeast-1.amazonaws.com/
# If blank, docker.io will be used. If specified, should have a trailing slash.
ARG REGISTRY=""
# Registry for public images such as debian, alpine, or postgres.
ARG PUBLIC_REGISTRY=""
# Public images may be mirrored into the private registry, with e.g. Skopeo
# ARG PUBLIC_REGISTRY=$REGISTRY

# Base image for build and test
ARG BUILD_BASE_IMAGE_NAME=${PUBLIC_REGISTRY}hexpm/elixir
ARG BUILD_BASE_IMAGE_TAG=${ELIXIR_VER}-erlang-${OTP_VER}-${BASE_OS}-${BUILD_OS_VER}

# Base for final prod image
ARG PROD_BASE_IMAGE_NAME=${PUBLIC_REGISTRY}${BASE_OS}
ARG PROD_BASE_IMAGE_TAG=$PROD_OS_VER

# App name, used to name directories
ARG APP_NAME=app

# Dir where app is installed
ARG APP_DIR=/app

# OS user for app to run under
# nonroot:x:65532:65532:nonroot:/home/nonroot:/usr/sbin/nologin
# nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
ARG APP_USER=nonroot
# OS group that app runs under
ARG APP_GROUP=$APP_USER
# OS numeric user and group id
ARG APP_USER_ID=65532
ARG APP_GROUP_ID=$APP_USER_ID

ARG LANG=C.UTF-8

# Elixir release env to build
ARG MIX_ENV=prod

# Name of Elixir release
# This should match mix.exs releases()
ARG RELEASE=prod

# App listen port
ARG APP_PORT=4000

# Allow additional packages to be injected into builds
ARG RUNTIME_PACKAGES=""
ARG DEV_PACKAGES=""


# Create build base image with OS dependencies
FROM ${BUILD_BASE_IMAGE_NAME}:${BUILD_BASE_IMAGE_TAG} AS build-os-deps
    ARG APK_UPDATE
    ARG APK_UPGRADE

    ARG APP_DIR
    ARG APP_GROUP
    ARG APP_GROUP_ID
    ARG APP_USER
    ARG APP_USER_ID

    # Create OS user and group to run app under
    # https://wiki.alpinelinux.org/wiki/Setting_up_a_new_user#adduser
    RUN if ! grep -q "$APP_USER" /etc/passwd; \
        then addgroup -g "$APP_GROUP_ID" -S "$APP_GROUP" && \
        adduser -u "$APP_USER_ID" -S "$APP_USER" -G "$APP_GROUP" -h "$APP_DIR"; fi

    # Install tools and libraries to build binary libraries
    # See https://wiki.alpinelinux.org/wiki/Local_APK_cache for details
    # on the local cache and need for the symlink
    RUN --mount=type=cache,id=apk,target=/var/cache/apk,sharing=locked \
        set -exu && \
        ln -s /var/cache/apk /etc/apk/cache && \
        $APK_UPDATE && $APK_UPGRADE && \
        apk add --no-progress nodejs npm && \
        # Get private repos
        apk add --no-progress openssh && \
        # Build binary libraries
        # apk add --no-progress alpine-sdk && \
        apk add --no-progress git build-base

    # Database command line clients to check if DBs are up when performing integration tests
    # RUN apk add --no-progress postgresql-client mysql-client
    # RUN apk add --no-progress --no-cache curl gnupg --virtual .build-dependencies -- && \
    #     curl -O https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/msodbcsql17_17.5.2.1-1_amd64.apk && \
    #     curl -O https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/mssql-tools_17.5.2.1-1_amd64.apk && \
    #     echo y | apk add --allow-untrusted msodbcsql17_17.5.2.1-1_amd64.apk mssql-tools_17.5.2.1-1_amd64.apk && \
    #     apk del .build-dependencies && rm -f msodbcsql*.sig mssql-tools*.apk
    # ENV PATH="/opt/mssql-tools/bin:${PATH}"

# Get Elixir deps
FROM build-os-deps AS build-deps-get
    ARG APP_DIR
    ENV HOME=$APP_DIR

    WORKDIR $APP_DIR

    RUN mix 'do' local.rebar --force, local.hex --force

    # Copy only the minimum files needed for deps, improving caching
    COPY --link config ./config
    COPY --link mix.exs ./
    COPY --link mix.lock ./

    COPY --link .env.defaul[t] ./

    # Add private repo for Oban
    RUN --mount=type=secret,id=oban_license_key \
        --mount=type=secret,id=oban_key_fingerprint \
        if test -s /run/secrets/oban_license_key; then \
            mix hex.repo add oban https://getoban.pro/repo \
                --fetch-public-key "$(cat /run/secrets/oban_key_fingerprint)" \
                --auth-key "$(cat /run/secrets/oban_license_key)"; \
        fi

    # Run deps.get with optional authentication to access private repos
    RUN --mount=type=ssh \
        --mount=type=secret,id=access_token \
        # Access private repos using ssh identity
        # https://docs.docker.com/engine/reference/commandline/buildx_build/#ssh
        # https://stackoverflow.com/questions/73263731/dockerfile-run-mount-type-ssh-doesnt-seem-to-work
        # Copying a predefined known_hosts file would be more secure, but would need to be maintained
        if test -n "$SSH_AUTH_SOCK"; then \
            mkdir -p /etc/ssh && \
            ssh-keyscan github.com > /etc/ssh/ssh_known_hosts && \
            mix deps.get; \
        # Access private repos using access token
        elif test -s /run/secrets/access_token; then \
            GIT_ASKPASS=/run/secrets/access_token mix deps.get; \
        else \
            mix deps.get; \
        fi


# Create base image for tests
FROM build-deps-get AS test-image
    ARG APP_DIR

    ENV MIX_ENV=test

    WORKDIR $APP_DIR

    COPY --link .env.tes[t] ./

    # Compile deps separately from app, improving Docker caching
    RUN mix deps.compile

    RUN mix esbuild.install --if-missing

    # Use glob pattern to deal with files which may not exist
    # Must have at least one existing file
    COPY --link .formatter.exs coveralls.jso[n] .credo.ex[s] dialyzer-ignor[e] trivy.yam[l] ./

    RUN mix dialyzer --plt

    COPY --link li[b] ./lib
    COPY --link app[s] ./apps

    COPY --link we[b] ./web
    COPY --link template[s] ./templates

    # Erlang src files
    COPY --link sr[c] ./src
    COPY --link includ[e] ./include

    COPY --link priv ./priv
    COPY --link test ./test
    # COPY --link bi[n] ./bin

    # RUN set -a && . ./.env.test && set +a && \
    #     env && \
    #     mix compile --warnings-as-errors

    RUN mix compile --warnings-as-errors

    # For umbrella, using `mix cmd` ensures each app is compiled in
    # isolation https://github.com/elixir-lang/elixir/issues/9407
    # RUN mix cmd mix compile --warnings-as-errors

    # Add test libraries
    # RUN yarn global add newman
    # RUN yarn global add newman-reporter-junitfull

    # COPY --link Postman ./Postman

# Create Elixir release
FROM build-deps-get AS prod-release
    ARG APP_DIR
    ARG RELEASE
    ARG MIX_ENV

    WORKDIR $APP_DIR

    COPY --link .env.pro[d] ./

    # Compile deps separately from application for better caching.
    # Doing "mix 'do' compile, assets.deploy" in a single stage is worse
    # because a single line of code changed causes a complete recompile.

    # RUN set -a && . ./.env.prod && set +a && \
    #     env && \
    #     mix deps.compile

    RUN mix deps.compile

    RUN mix esbuild.install --if-missing

    RUN mkdir -p ./assets

    # Install JavaScript deps
    COPY --link assets/package.jso[n] assets/package.json
    COPY --link assets/package-lock.jso[n] assets/package-lock.json
    COPY --link assets/yarn.loc[k] assets/yarn.lock
    COPY --link assets/brunch-config.j[s] assets/brunch-config.js

    WORKDIR ${APP_DIR}/assets

    RUN --mount=type=cache,target=~/.npm,sharing=locked \
        set -exu && \
        mkdir -p ./assets && \
        corepack enable && \
        # yarn --cwd ./assets install --prod
        yarn install --prod
        # npm install
        # npm --prefer-offline --no-audit --progress=false --loglevel=error ci
        # node node_modules/brunch/bin/brunch build

    # RUN --mount=type=cache,target=~/.npm,sharing=locked \
    #     npm run deploy
    #
    # Generate assets the really old way
    # RUN --mount=type=cache,target=~/.npm,sharing=locked \
    #     node node_modules/webpack/bin/webpack.js --mode production

    WORKDIR $APP_DIR

    # Compile assets with esbuild
    COPY --link li[b] ./lib
    COPY --link app[s] ./apps
    COPY --link we[b] ./web

    # Erlang src files
    COPY --link sr[c] ./src
    COPY --link includ[e] ./include

    COPY --link priv ./priv
    COPY --link assets ./assets

    COPY --link bi[n] ./bin

    RUN mix assets.deploy

    # RUN esbuild default --minify
    # RUN mix phx.digest

    # For umbrella, using `mix cmd` ensures each app is compiled in
    # isolation https://github.com/elixir-lang/elixir/issues/9407
    # RUN mix cmd mix compile --warnings-as-errors

    # RUN set -a && . ./.env.prod && set +a && \
    #     env && \
    #     mix compile --verbose --warnings-as-errors

    RUN mix compile --warnings-as-errors

    # Build release
    COPY --link rel ./rel
    RUN mix release "$RELEASE"


# Create base image for prod with everything but the code release
FROM ${PROD_BASE_IMAGE_NAME}:${PROD_BASE_IMAGE_TAG} AS prod-base
    ARG APK_UPDATE
    ARG APK_UPGRADE
    ARG RUNTIME_PACKAGES

    ARG LANG

    ARG APP_DIR
    ARG APP_GROUP
    ARG APP_GROUP_ID
    ARG APP_USER
    ARG APP_USER_ID

    # Create OS user and group to run app under
    # https://wiki.alpinelinux.org/wiki/Setting_up_a_new_user#adduser
    RUN if ! grep -q "$APP_USER" /etc/passwd; \
        then addgroup -g $APP_GROUP_ID -S "$APP_GROUP" && \
        adduser -u $APP_USER_ID -S "$APP_USER" -G "$APP_GROUP" -h "$APP_DIR"; fi

    # Install Alpine libraries needed at runtime
    # See https://wiki.alpinelinux.org/wiki/Local_APK_cache for details
    # on the local cache and need for the symlink
    RUN --mount=type=cache,id=apk,target=/var/cache/apk,sharing=locked \
        set -ex && \
        ln -s /var/cache/apk /etc/apk/cache && \
        # Upgrading ensures that we get the latest packages, but makes the build nondeterministic
        $APK_UPDATE && $APK_UPGRADE && \
        # apk add --no-progress $RUNTIME_PACKAGES && \
        # apk add --no-progress shared-mime-info tzdata && \
        # https://github.com/krallin/tini
        # apk add --no-progress tini && \
        # Make DNS resolution more reliable
        # https://github.com/sourcegraph/godockerize/commit/5cf4e6d81720f2551e6a7b2b18c63d1460bbbe4e
        # apk add --no-progress bind-tools && \
        # Support outbound TLS connections
        apk add --no-progress ca-certificates && \
        # Allow app to listen on HTTPS
        # May not be needed if HTTPS is handled outside the application, e.g. in load balancer
        apk add --no-progress openssl && \
        # Erlang deps
        apk add --no-progress ncurses-libs libgcc libstdc++


# Create final prod image which gets deployed
FROM prod-base AS prod
    ARG LANG

    ARG APP_DIR
    ARG APP_NAME
    ARG APP_USER
    ARG APP_GROUP
    ARG APP_PORT

    ARG MIX_ENV
    ARG RELEASE

    # Set environment vars that do not change. Secrets like SECRET_KEY_BASE and
    # environment-specific config such as DATABASE_URL should be set at runtime.
    ENV HOME=$APP_DIR \
        LANG=$LANG \
        RELEASE=$RELEASE \
        MIX_ENV=$MIX_ENV \
        # Writable tmp directory for releases
        RELEASE_TMP="/run/${APP_NAME}"

    # The app needs to be able to write to a tmp directory on startup, which by
    # default is under the release. This can be changed by setting RELEASE_TMP to
    # /tmp or, more securely, /run/foo
    RUN \
        # Create app dirs
        mkdir -p "/run/${APP_NAME}" && \
        # mkdir -p "/etc/foo" && \
        # mkdir -p "/var/lib/foo" && \
        # Make dirs writable by app
        chown -R "${APP_USER}:${APP_GROUP}" \
            # Needed for RELEASE_TMP
            "/run/${APP_NAME}"
            # "/var/lib/foo"

    # USER $APP_USER

    # Setting WORKDIR after USER makes directory be owned by the user.
    # Setting it before makes it owned by root, which is more secure.
    WORKDIR $APP_DIR

    # When using a startup script, copy to /app/bin
    # COPY --link bi[n] ./bin

    USER $APP_USER:$APP_GROUP

    # Chown files while copying. Running "RUN chown -R app:app /app"
    # adds an extra layer which is about 10Mb, a huge difference if the
    # app image is around 20Mb.

    # TODO: For more security, change specific files to have group read/execute
    # permissions while leaving them owned by root

    # When using a startup script, unpack release under "/app/current" dir
    # WORKDIR $APP_DIR/current

    COPY --from=prod-release --chown="$APP_USER:$APP_GROUP" "/app/_build/${MIX_ENV}/rel/${RELEASE}" ./

    EXPOSE $APP_PORT

    # Erlang EPMD port
    EXPOSE 4369

    # Intra-Erlang communication ports
    EXPOSE 9000-9010

    # :erpc default port
    EXPOSE 9090

    # "bin" is the directory under the unpacked release, and "prod" is the name
    # of the release top level script, which should match the RELEASE var.
    # ENTRYPOINT ["bin/prod"]

    # Run under init to avoid zombie processes
    # https://github.com/krallin/tini
    # ENTRYPOINT ["/sbin/tini", "--", "bin/prod"]

    # Wrapper script which runs e.g. migrations before starting
    ENTRYPOINT ["bin/start-docker"]

    # Run app in foreground
    # CMD ["start"]


# Copy build artifacts to host
FROM scratch AS artifacts
    ARG MIX_ENV
    ARG RELEASE

    # COPY --from=prod-release "/app/_build/${MIX_ENV}/rel/${RELEASE}" /release
    # COPY --from=prod-release /app/_build/${MIX_ENV}/${RELEASE}-*.tar.gz /release
    COPY --from=prod-release /app/priv/static /static


# Default target
FROM prod
