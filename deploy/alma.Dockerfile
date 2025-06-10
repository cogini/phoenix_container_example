# Build app
# Deploy using Alma Linux

ARG BASE_OS=almalinux

# Specify versions of Erlang, Elixir, and base OS.
# Choose a combination supported by https://hub.docker.com/r/hexpm/elixir/tags

ARG ELIXIR_VER=1.18.3
ARG OTP_VER=27.3.4

# https://hub.docker.com/_/almalinux
ARG BUILD_OS_VER=9
ARG PROD_OS_VER=9

# Specify snapshot explicitly to get repeatable builds, see https://snapshot.debian.org/
# The tag without a snapshot (e.g., bullseye-slim) includes the latest snapshot.
# ARG SNAPSHOT_VER=20230612
ARG SNAPSHOT_VER=""

# ARG NODE_VER=16.14.1
ARG NODE_VER=lts
ARG NODE_MAJOR=20
ARG YARN_VER=1.22.22

# Docker registry for internal images, e.g. 123.dkr.ecr.ap-northeast-1.amazonaws.com/
# If blank, docker.io will be used. If specified, should have a trailing slash.
ARG REGISTRY=""
# Registry for public images such as debian, alpine, or postgres.
ARG PUBLIC_REGISTRY=""
# Public images may be mirrored into the private registry, with e.g. Skopeo
# ARG PUBLIC_REGISTRY=$REGISTRY

# Base image for build and test
ARG BUILD_BASE_IMAGE_NAME=${PUBLIC_REGISTRY}${BASE_OS}
# ARG BUILD_BASE_IMAGE_TAG=$PROD_OS_VER
ARG BUILD_BASE_IMAGE_TAG=9

# Base for final prod image
ARG PROD_BASE_IMAGE_NAME=${PUBLIC_REGISTRY}${BASE_OS}
# ARG PROD_BASE_IMAGE_TAG=$PROD_OS_VER
ARG PROD_BASE_IMAGE_TAG=9

# Intermediate image for files copied to prod
ARG INSTALL_BASE_IMAGE_NAME=$PROD_BASE_IMAGE_NAME
ARG INSTALL_BASE_IMAGE_TAG=$PROD_BASE_IMAGE_TAG

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
# ARG LANG=en_US.UTF-8

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
    ARG LANG
    ARG SNAPSHOT_VER
    ARG RUNTIME_PACKAGES

    ARG OTP_VER
    ARG ELIXIR_VER
    ARG REBAR_VER
    ARG NODE_VER
    ARG NODE_MAJOR

    ARG APP_DIR
    ARG APP_GROUP
    ARG APP_GROUP_ID
    ARG APP_USER
    ARG APP_USER_ID

    # Install tools and libraries to build binary libraries
    RUN --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
        set -ex && \
        # add config-manager plugin
        dnf install -y dnf-plugins-core && \
        # dnf config-manager --set-enabled powertools && \
        # dnf config-manager --set-enabled devel && \
        dnf install -y epel-release && \
        /usr/bin/crb enable && \
        dnf upgrade -y && \
        # dnf makecache --refresh && \
        dnf group install -y 'Development Tools' && \
        dnf builddep erlang -y && \
        # dnf install -y --allowerasing \
        dnf install -y \
            cmake \
            cmake3 \
            curl \
            git \
            gpg \
            make \
            # useradd and groupadd
            shadow-utils \
            unzip \
            wget \
        # http://erlang.org/doc/installation_guide/INSTALL.html#required-utilities
        # https://github.com/asdf-vm/asdf-erlang
        # bin/build-install-asdf-deps-centos && \
        # https://github.com/asdf-vm/asdf-erlang/issues/206
        # rpm --eval '%{_arch}' && \
            # autoconf \
            # automake \
            # bison \
            # flex \
            # gcc \
            # gcc-c++ \
            # fop \
            # java-1.8.0-openjdk-devel \
            # java-11-openjdk-devel \
            libffi-devel \
            libiodbc \
            # libtool \
            libxslt \
            libxslt-devel \
            libyaml \
            # libyaml-devel \
            lksctp-tools-devel \
            mesa-libGL-devel \
            ncurses-devel \
            openssl \
            openssl-devel \
            readline-devel \
            sqlite-devel \
            unixODBC-devel \
            wxGTK3 wxGTK3-devel wxGTK3-gl wxGTK3-media
            # wxBase3 \
            # erlang-odbc
        # && \
        # dnf clean all
        # dnf clean all && rm -rf /var/cache/dnf

        # https://github.com/esl/packages/blob/master/builders/erlang_centos.Dockerfile

    # Create OS user and group to run app under
    RUN if ! grep -q "$APP_USER" /etc/passwd; \
        then groupadd -g "$APP_GROUP_ID" "$APP_GROUP" && \
        useradd -l -u "$APP_USER_ID" -g "$APP_GROUP" -d "$APP_DIR" -s /usr/sbin/nologin "$APP_USER" && \
        rm -f /var/log/lastlog && rm -f /var/log/faillog; fi

    ENV HOME=$APP_DIR

    WORKDIR $APP_DIR

    COPY  bi[n] ./bin
    COPY .tool-versions ./

    # Set up ASDF
    RUN set -ex && \
        export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH && \
        bin/build-install-asdf-init

    ENV ASDF_DIR="$HOME/.asdf"
    ENV PATH=$ASDF_DIR/bin:$ASDF_DIR/shims:$PATH

    # Install using asdf
    RUN set -ex && \
        # Install using .tool-versions versions
        asdf install && \
        # asdf install erlang "$OTP_VER" && \
        # asdf install elixir "$ELIXIR_VER" && \
        # asdf install nodejs "$NODE_VER" && \
        # asdf install yarn "$YARN_VER" && \
        # export RPM_ARCH=$(rpm --eval '%{_arch}') && \
        # echo "RPM_ARCH=$RPM_ARCH" && \
        # if [ "${RPM_ARCH}" = "x86_64" ]; then \
        #   # Install Erlang from erlang-solutions RPM
        #   bin/build-install-deps-alma; \
        # else \
        #   # Install using asdf
        #   # bin/build-install-asdf
        #   asdf install erlang; \
        # fi && \
        erl -version && \
        elixir -v && \
        node -v

# Get Elixir deps
FROM build-os-deps AS build-deps-get
    ARG APP_DIR
    ENV HOME=$APP_DIR

    WORKDIR $APP_DIR

    RUN mix 'do' local.rebar --force, local.hex --force

    COPY --link .env.defaul[t] ./

    # Copy only the minimum files needed for deps, improving caching
    COPY --link mix.exs ./
    COPY --link mix.lock ./
    COPY --link config ./config

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

    # Use glob pattern to deal with files which may not exist
    # Must have at least one existing file
    COPY --link .formatter.ex[s] coveralls.jso[n] .credo.ex[s] dialyzer-ignor[e] trivy.yam[l] ./

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
    # RUN npm install -g newman
    # RUN npm install -g newman-reporter-junitfull

    # COPY --link Postman ./Postman

# Create Elixir release
FROM build-deps-get AS prod-release
    ARG APP_DIR
    ARG RELEASE
    ARG MIX_ENV

    WORKDIR $APP_DIR

    COPY --link .env.pro[d] ./

    # Compile deps separately from the application for better Docker caching.
    # Doing "mix 'do' compile, assets.deploy" in a single stage is worse
    # because a single line of code changed causes a complete recompile.

    # RUN set -a && . ./.env.prod && set +a && \
    #     env && \
    #     mix deps.compile

    RUN mix deps.compile

    # RUN mix esbuild.install --if-missing

    # Build assets
    RUN mkdir -p ./assets

    # Install JavaScript deps
    COPY --link assets/package.jso[n] assets/package.json
    COPY --link assets/package-lock.jso[n] assets/package-lock.json
    COPY --link assets/yarn.loc[k] assets/yarn.lock
    COPY --link assets/brunch-config.j[s] assets/brunch-config.js

    WORKDIR ${APP_DIR}/assets

    # Install JavaScript dependencies
    RUN --mount=type=cache,target=~/.npm,sharing=locked \
        set -exu && \
        # corepack enable && corepack enable npm && \
        # yarn --cwd ./assets install --prod
        yarn install --prod
        # pnpm install --prod
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

    RUN mix assets.setup

    COPY --link li[b] ./lib
    COPY --link app[s] ./apps
    COPY --link we[b] ./web

    # Erlang src files
    COPY --link sr[c] ./src
    COPY --link includ[e] ./include

    COPY --link template[s] ./templates

    COPY --link priv ./priv
    COPY --link assets ./assets

    COPY --link bi[n] ./bin

    # For umbrella, using `mix cmd` ensures each app is compiled in
    # isolation https://github.com/elixir-lang/elixir/issues/9407
    # RUN mix cmd mix compile --warnings-as-errors

    # RUN set -a && . ./.env.prod && set +a && \
    #     env && \
    #     mix compile --verbose --warnings-as-errors

    RUN mix compile --warnings-as-errors

    # RUN esbuild default --minify
    # RUN mix phx.digest
    RUN mix assets.deploy

    # Build release
    COPY --link rel ./rel

    # Generate systemd and deploy scripts
    # RUN mix do systemd.init, systemd.generate, deploy.init, deploy.generate

    RUN mix release "$RELEASE"

    # Create revision for CodeDeploy
    # WORKDIR /revision
    # COPY appspec.yml ./
    # RUN set -exu && \
    #     mkdir -p etc bin systemd && \
    #     chmod +x /app/bin/* && \
    #     cp /app/bin/* ./bin/ && \
    #     cp /app/_build/${MIX_ENV}/systemd/lib/systemd/system/* ./systemd/ && \
    #     cp /app/_build/${MIX_ENV}/${RELEASE}-*.tar.gz "./${RELEASE}.tar.gz" && \
    #     zip -r /revision.zip . && \
    #     rm -rf /revision/*

# Create staging image for files which are copied into final prod image
FROM ${INSTALL_BASE_IMAGE_NAME}:${INSTALL_BASE_IMAGE_TAG} AS prod-install
    ARG LANG
    ARG SNAPSHOT_VER
    ARG RUNTIME_PACKAGES

    # https://groups.google.com/g/cloudlab-users/c/Re6Jg7oya68?pli=1

    RUN --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
        set -exu && \
        # dnf makecache --refresh && \
        dnf upgrade -y && \
        dnf install -y \
            ca-certificates \
            curl \
            gnupg-agent \
            # software-properties-common \
            gpg \
            unzip \
            lsb-release \
            # Needed by Erlang VM
            libtinfo6 \
            # Additional libs
            libstdc++6 \
            libgcc-s1 \
            locales \
            openssl
            # $RUNTIME_PACKAGES \
        # && \
        # dnf clean all
        # dnf clean all && rm -rf /var/cache/yum

# Creating minimal CentOS docker image from scratch
# https://gist.github.com/silveraid/e6bdf78441c731a30a66fc6adca6f4b5
# https://www.mankier.com/8/microdnf
# https://git.rockylinux.org/rocky/images/-/blob/main/base/scripts/build-container-rootfs.sh


# Create base image for prod with everything but the code release
FROM ${PROD_BASE_IMAGE_NAME}:${PROD_BASE_IMAGE_TAG} AS prod-base
    ARG SNAPSHOT_VER
    ARG RUNTIME_PACKAGES

    ARG LANG

    ARG APP_NAME
    ARG APP_DIR
    ARG APP_GROUP
    ARG APP_GROUP_ID
    ARG APP_USER
    ARG APP_USER_ID

    RUN --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
        set -exu \
        # dnf makecache --refresh && \
        dnf upgrade -y && \
        dnf install -y \
            # Enable the app to make outbound SSL calls.
            ca-certificates \
            # Run health checks and get ECS metadata
            # curl \
            jq \
            openssl  \
            # useradd and groupadd
            shadow-utils \
            wget
        #    && \
        # localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
        # localedef -i en_US -c -f UTF-8 en_US.UTF-8 && \
        # locale -a | grep -E 'en_US|C'
        # dnf clean all
        # dnf clean all && rm -rf /var/cache/dnf

    # Create OS user and group to run app under
    RUN if ! grep -q "$APP_USER" /etc/passwd; \
        then groupadd -g "$APP_GROUP_ID" "$APP_GROUP" && \
        useradd -l -u "$APP_USER_ID" -g "$APP_GROUP" -d "$APP_DIR" -s /usr/sbin/nologin "$APP_USER" && \
        rm -f /var/log/lastlog && rm -f /var/log/faillog; fi && \
        chown "${APP_USER}:${APP_GROUP}" "$APP_DIR"

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
        # RELEASE=$RELEASE \
        # MIX_ENV=$MIX_ENV \
        # Writable tmp directory for releases
        RELEASE_TMP="/run/${APP_NAME}"

    # The app needs to be able to write to a tmp directory on startup, which by
    # default is under the release. This can be changed by setting RELEASE_TMP to
    # /tmp or, more securely, /run/foo
    RUN set -exu && \
        # Create app dirs
        mkdir -p "/run/${APP_NAME}" && \
        # mkdir -p "/etc/foo" && \
        # mkdir -p "/var/lib/foo" && \
        # Make dirs writable by app
        chown -R "${APP_USER}:${APP_GROUP}" \
            # Needed for RELEASE_TMP
            "/run/${APP_NAME}"
            # "/var/lib/foo"

    # Copy CodeDeploy revision into prod image for publishing later
    # This could be put in a separate target, but it's faster to do it from prod test
    # COPY --from=prod-release --chown="$APP_USER:$APP_GROUP" /revision.zip /revision.zip

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

# Dev image which mounts code from local filesystem
FROM build-os-deps AS dev
    ARG LANG

    ARG APP_DIR
    ARG APP_GROUP
    ARG APP_NAME
    ARG APP_USER

    ARG DEV_PACKAGES

    # Set environment vars used by the app
    ENV HOME=$APP_DIR \
        LANG=$LANG

    RUN set -exu && \
        # Create app dirs
        mkdir -p "/run/${APP_NAME}" && \
        # Make dirs writable by app
        chown -R "${APP_USER}:${APP_GROUP}" \
            # Needed for RELEASE_TMP
            "/run/${APP_NAME}"

    RUN --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
        set -exu && \
        dnf install -y \
            inotify-tools \
            openssh-clients \
            sudo \
            # for chsh
            util-linux-user
            # $DEV_PACKAGES \
        # && \
        # dnf clean all
        # yum clean all && rm -rf /var/cache/yum

    RUN chsh --shell /bin/bash "$APP_USER"

    USER $APP_USER:$APP_GROUP

    WORKDIR $APP_DIR

    RUN mix 'do' local.rebar --force, local.hex --force

    # RUN mix esbuild.install --if-missing

# Copy build artifacts to host
FROM build-os-deps AS codedeploy-revision
    ARG MIX_ENV
    ARG RELEASE
    ARG APP_USER
    ARG APP_GROUP

    # COPY --from=prod-release --chown="$APP_USER:$APP_GROUP" /revision.zip /revision.zip

    WORKDIR /revision
    COPY --from=prod-release /app/_build/${MIX_ENV}/${RELEASE}-*.tar.gz ./
    COPY --from=prod-release "/app/_build/${MIX_ENV}/systemd/lib/systemd/system" ./systemd
    COPY bin ./bin

    RUN mkdir -p etc

# Copy build artifacts to host
FROM scratch AS artifacts
    ARG MIX_ENV
    ARG RELEASE

    # COPY --from=prod-release "/app/_build/${MIX_ENV}/rel/${RELEASE}" /release
    # COPY --from=prod-release /app/_build/${MIX_ENV}/${RELEASE}-*.tar.gz /release
    # COPY --from=prod-release "/app/_build/${MIX_ENV}/systemd/lib/systemd/system" /systemd
    # COPY --from=prod-release /app/_build/${MIX_ENV} ${MIX_ENV}
    COPY --from=prod-release /app/_build /_build
    # COPY --from=prod-release /app/priv/static /static

# Default target
FROM prod
