# Build app
# Deploy using Alma Linux

# Specify versions of Erlang, Elixir, and base OS.
# Choose a combination supported by https://hub.docker.com/r/hexpm/elixir/tags

ARG ELIXIR_VER=1.19.1
ARG OTP_VER=28.1.1

# https://hub.docker.com/_/almalinux
ARG BUILD_OS_VER=8
ARG PROD_OS_VER=8

ARG NODE_MAJOR=24
ARG NODE_VER=24.0.1
ARG YARN_VER=1.22.22

# Docker registry for internal images, e.g., 123.dkr.ecr.ap-northeast-1.amazonaws.com/
# If blank, docker.io will be used. If specified, should have a trailing slash.
ARG REGISTRY=""
# Registry for public images such as debian, alpine, or postgres.
ARG PUBLIC_REGISTRY=""
# Public images may be mirrored into the private registry with, e.g., Skopeo
# ARG PUBLIC_REGISTRY=$REGISTRY

# OS user for app to run under
# nonroot:x:65532:65532:nonroot:/home/nonroot:/usr/sbin/nologin
# nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin

ARG LANG=C.UTF-8
# ARG LANG=en_US.UTF-8

# Elixir release env to build
ARG MIX_ENV=prod

# Name of Elixir release
# This should match mix.exs releases()
ARG RELEASE=prod

# Build number to embed into release for tracking
ARG BUILD_NUM=1

# Support injecting additional packages into build stages.
# These variables must always have something defined, so default values are redundant.
ARG RUNTIME_PACKAGES="ca-certificates"
# Packages used for interactive development
ARG DEV_PACKAGES="inotify-tools"


# Create build base image with OS dependencies
FROM ${PUBLIC_REGISTRY}almalinux:${BUILD_OS_VER} AS build-os-deps

# Create OS user and group to run app under
RUN if ! grep -q nonroot /etc/passwd; then \
    groupadd -g 65532 nonroot ; \
    useradd -l -u 65532 -g nonroot -d /app -s /usr/sbin/nologin nonroot ; \
    rm -f /var/log/lastlog ; rm -f /var/log/faillog ; fi

ARG RUNTIME_PACKAGES

# Install tools and libraries to build binary libraries
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
    set -ex ; \
    # add config-manager plugin
    dnf install -y --nodocs dnf-plugins-core ; \
    # dnf config-manager --set-enabled powertools ; \
    # dnf config-manager --set-enabled devel ; \
    dnf install -y epel-release ; \
    /usr/bin/crb enable ; \
    dnf upgrade -y ; \
    # dnf makecache --refresh ; \
    dnf group install -y 'Development Tools' ; \
    dnf builddep erlang -y ; \
    dnf install -y --nodocs --allowerasing \
        cmake \
        cmake3 \
        curl \
        git \
        # glibc-langpack -en \
        glibc-minimal-langpack \
        gpg \
        make \
        # useradd and groupadd
        shadow-utils \
        unzip \
        wget \
    # http://erlang.org/doc/installation_guide/INSTALL.html#required-utilities
    # https://github.com/asdf-vm/asdf-erlang
    # bin/build-install-asdf-deps-centos ; \
    # https://github.com/asdf-vm/asdf-erlang/issues/206
    # rpm --eval '%{_arch}' ; \
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
        # $RUNTIME_PACKAGES \
    # ; \
    # dnf clean all
    # dnf clean all ; rm -rf /var/cache/dnf

# https://github.com/esl/packages/blob/master/builders/erlang_centos.Dockerfile

ENV HOME=/app

WORKDIR /app

COPY  bi[n] ./bin

# Set up ASDF
RUN set -ex ; \
    export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH" ; \
    bin/build-install-asdf-init

ENV ASDF_DIR="$HOME/.asdf"
ENV PATH=$ASDF_DIR/bin:$ASDF_DIR/shims:$PATH

COPY .tool-versions ./

ARG ELIXIR_VER
ARG NODE_MAJOR
ARG NODE_VER
ARG OTP_VER
ARG REBAR_VER
ARG YARN_VER

# Install using asdf
RUN set -ex ; \
    # Install using .tool-versions versions
    asdf install ; \
    # asdf install erlang "$OTP_VER" ; \
    # asdf install elixir "$ELIXIR_VER" ; \
    # asdf install nodejs "$NODE_VER" ; \
    # asdf install yarn "$YARN_VER" ; \
    # asdf install rebar "${REBAR_VER}" ; \
    # export RPM_ARCH=$(rpm --eval '%{_arch}') ; \
    # echo "RPM_ARCH=$RPM_ARCH" ; \
    # if [ "${RPM_ARCH}" = "x86_64" ]; then \
    #   # Install Erlang from erlang-solutions RPM
    #   bin/build-install-deps-alma; \
    # else \
    #   # Install using asdf
    #   # bin/build-install-asdf
    #   asdf install erlang; \
    # fi ; \
    erl -version ; \
    elixir -v ; \
    node -v


# Get Elixir deps
FROM build-os-deps AS build-deps-get
ARG LANG

ENV HOME=/app

WORKDIR /app

RUN mix 'do' local.rebar --force, local.hex --force

# COPY --link .env.defaul[t] ./

# Copy only the minimum files needed for deps, improving caching
COPY --link mix.exs mix.lock ./
# COPY --link config ./config

# Add private repo for Oban
RUN --mount=type=secret,id=oban_license_key --mount=type=secret,id=oban_key_fingerprint \
    if test -s /run/secrets/oban_license_key; then \
        mix hex.repo add oban https://getoban.pro/repo \
            --fetch-public-key "$(cat /run/secrets/oban_key_fingerprint)" \
            --auth-key "$(cat /run/secrets/oban_license_key)"; \
    fi

# Run deps.get with optional authentication to access private repos
RUN --mount=type=ssh --mount=type=secret,id=access_token \
    # Access private repos using ssh identity
    # https://docs.docker.com/engine/reference/commandline/buildx_build/#ssh
    # https://stackoverflow.com/questions/73263731/dockerfile-run-mount-type-ssh-doesnt-seem-to-work
    # Copying a predefined known_hosts file would be more secure, but would need to be maintained
    if test -n "$SSH_AUTH_SOCK"; then \
        set -exu ; \
        mkdir -p /etc/ssh ; \
        ssh-keyscan github.com > /etc/ssh/ssh_known_hosts ; \
        mix deps.get ; \
    # Access private repos using access token
    elif test -s /run/secrets/access_token; then \
        GIT_ASKPASS=/run/secrets/access_token mix deps.get ; \
    else \
        mix deps.get ; \
    fi


# Create base image for tests
FROM build-deps-get AS test-image
ARG LANG

ENV MIX_ENV=test

WORKDIR /app

# Postman tests
# RUN npm install -g newman
# RUN npm install -g newman-reporter-junitfull
COPY --link Postma[n] ./Postman

# COPY --link config ./config
COPY --link config/config.exs "config/${MIX_ENV}.exs" ./config/

# Compile deps separately from app, improving Docker caching
RUN mix deps.compile

# Use glob pattern to deal with files which may not exist
# Must have at least one existing file
COPY --link .formatter.ex[s] coveralls.jso[n] .credo.ex[s] dialyzer-ignor[e] trivy.yam[l] ./

# Generate Dialyzer files for deps
RUN mix dialyzer --plt

COPY --link li[b] ./lib
COPY --link app[s] ./apps

# Old Phoenix
COPY --link we[b] ./web

# Erlang files
COPY --link sr[c] ./src
COPY --link includ[e] ./include
COPY --link template[s] ./templates

COPY --link priv ./priv
COPY --link test ./test
# COPY --link bi[n] ./bin

# Load environment vars when compiling
COPY --link .env.tes[t] ./
RUN if test -f .env.test ; then set -a ; . ./.env.test ; set +a ; env ; fi ; \
    mix compile --warnings-as-errors

# For umbrella, using `mix cmd` ensures each app is compiled in
# isolation https://github.com/elixir-lang/elixir/issues/9407
# RUN mix cmd mix compile --warnings-as-errors


# Create Elixir release
FROM build-deps-get AS prod-release
ARG LANG

WORKDIR /app

# Build assets
RUN mkdir -p ./assets

# Install JavaScript deps
COPY --link assets/package.jso[n] assets/package-lock.jso[n] assets/yarn.loc[k] assets/brunch-config.j[s] ./assets/

WORKDIR /app/assets

# Install JavaScript dependencies
RUN --mount=type=cache,target=~/.npm,sharing=locked \
    # corepack enable ; corepack enable npm ; \
    # yarn --cwd ./assets install --prod
    yarn install --prod
    # pnpm install --prod
    # npm install
    # npm run deploy
    # npm --prefer-offline --no-audit --progress=false --loglevel=error ci
    # node node_modules/brunch/bin/brunch build
    # node node_modules/webpack/bin/webpack.js --mode production

WORKDIR /app

# Compile deps separately from the application for better Docker caching.
# Doing "mix 'do' compile, assets.deploy" in a single stage is worse
# because a single line of code changed causes a complete recompile.

COPY --link .env.pro[d] ./

ARG MIX_ENV
# COPY --link config ./config
COPY --link config/config.exs "config/${MIX_ENV}.exs" ./config/

# Load environment vars when compiling
RUN if test -f .env.prod ; then set -a ; . ./.env.prod ; set +a ; env ; fi ; \
    mix deps.compile

COPY --link li[b] ./lib
COPY --link app[s] ./apps

# Old Phoenix
COPY --link we[b] ./web

# Erlang files
COPY --link sr[c] ./src
COPY --link includ[e] ./include
COPY --link template[s] ./templates

COPY --link priv ./priv
COPY --link assets ./assets

COPY --link bi[n] ./bin

# For umbrella, using `mix cmd` ensures each app is compiled in
# isolation https://github.com/elixir-lang/elixir/issues/9407
# RUN mix cmd mix compile --warnings-as-errors

RUN if test -f .env.prod ; then set -a ; . ./.env.prod ; set +a ; env ; fi ; \
    mix compile --warnings-as-errors

RUN mix assets.setup


RUN mix assets.deploy

# Build release
COPY --link config/runtime.exs ./config/

COPY --link rel ./rel

# Generate systemd and deploy scripts
# RUN mix do systemd.init, systemd.generate, deploy.init, deploy.generate

ARG RELEASE
RUN mix release "$RELEASE"

# ARG BUILD_NUM
# ARG ELIXIR_VER
# ARG OTP_VER
# ARG BUILD_OS_VER

# Create revision for CodeDeploy
# WORKDIR /revision
# COPY appspec.yml ./
# RUN set -exu ; \
#     mkdir -p etc bin lib systemd ; \
#     chmod +x /app/bin/* ; \
#     cp /app/bin/* ./bin/ ; \
#     cp /app/_build/${MIX_ENV}/systemd/lib/systemd/system/* ./systemd/ ; \
#     cp /app/_build/${MIX_ENV}/${RELEASE}-*.tar.gz "./${RELEASE}.tar.gz" ; \
#     echo "build: ${BUILD_NUM}" > build_meta.yml ; \
#     echo "elixir_ver: ${ELIXIR_VER}" >> build_meta.yml ; \
#     echo "otp_ver: ${OTP_VER}" >> build_meta.yml ; \
#     echo "build_os: alma" >> build_meta.yml ; \
#     echo "build_os_ver: ${BUILD_OS_VER}" >> build_meta.yml ; \
#     zip -r /revision.zip . ; \
#     rm -rf /revision/*

# Create release package for Ansible
# WORKDIR /ansible
# RUN set -exu ; \
#     mkdir -p _build/${MIX_ENV}/systemd/lib/systemd/system ; \
#     cp /app/_build/${MIX_ENV}/systemd/lib/systemd/system/* _build/${MIX_ENV}/systemd/lib/systemd/system/ ; \
#     # mkdir -p _build/${MIX_ENV}/deploy/bin ; \
#     # cp /app/_build/${MIX_ENV}/deploy/bin/* _build/${MIX_ENV}/deploy/bin/ ; \
#     # chmod +x /app/_build/${MIX_ENV}/deploy/bin/* ; \
#     mkdir -p bin lib ; \
#     cp /app/bin/* ./bin/ ; \
#     chmod +x ./bin/* ; \
#     cp /app/_build/${MIX_ENV}/${RELEASE}-*.tar.gz _build/${MIX_ENV}/ ; \
#     echo "build: ${BUILD_NUM}" > build_meta.yml ; \
#     echo "elixir_ver: ${ELIXIR_VER}" >> build_meta.yml ; \
#     echo "otp_ver: ${OTP_VER}" >> build_meta.yml ; \
#     echo "build_os: alma" >> build_meta.yml ; \
#     echo "build_os_ver: ${BUILD_OS_VER}" >> build_meta.yml ; \
#     zip -r /ansible.zip . ; \
#     rm -rf /ansible/*


# Create staging image for files which are copied into final prod image
FROM ${PUBLIC_REGISTRY}almalinux:${PROD_OS_VER} AS prod-install
ARG LANG

# https://groups.google.com/g/cloudlab-users/c/Re6Jg7oya68?pli=1

ARG RUNTIME_PACKAGES

RUN --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
    set -exu ; \
    # dnf makecache --refresh ; \
    dnf upgrade -y ; \
    dnf install -y --nodocs --allowerasing \
        ca-certificates \
        curl \
        gnupg-agent \
        # software-properties-common \
        # glibc-langpack -en \
        glibc-minimal-langpack \
        gpg \
        unzip \
        # jq \
        lsb-release \
        # Needed by Erlang VM
        # Additional libs
        libstdc++6 \
        libgcc-s1 \
        # locales \
        $RUNTIME_PACKAGES
    # dnf clean all
    # dnf clean all ; rm -rf /var/cache/yum

# Creating minimal CentOS docker image from scratch
# https://gist.github.com/silveraid/e6bdf78441c731a30a66fc6adca6f4b5
# https://www.mankier.com/8/microdnf
# https://git.rockylinux.org/rocky/images/-/blob/main/base/scripts/build-container-rootfs.sh


# Create base image for prod with everything but the code release
FROM ${PUBLIC_REGISTRY}almalinux:${PROD_OS_VER} AS prod-base

# Create OS user and group to run app under
RUN if ! grep -q nonroot /etc/passwd; then \
    groupadd -g 65532 nonroot ; \
    useradd -l -u 65532 -g nonroot -d /app -s /usr/sbin/nologin nonroot ; \
    rm -f /var/log/lastlog ; rm -f /var/log/faillog ; fi

ARG RUNTIME_PACKAGES

RUN --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
    set -exu ; \
    # dnf makecache --refresh ; \
    dnf upgrade -y ; \
    dnf install -y --nodocs --allowerasing \
        # Enable the app to make outbound SSL calls.
        ca-certificates \
        # Run health checks and get ECS metadata
        curl \
        # glibc-langpack -en \
        glibc-minimal-langpack \
        jq \
        # useradd and groupadd
        shadow-utils \
        wget \
        $RUNTIME_PACKAGES
    # dnf clean all
    # dnf clean all ; rm -rf /var/cache/dnf

ARG LANG

# Set environment vars that do not change. Secrets like SECRET_KEY_BASE and
# environment-specific config such as DATABASE_URL are set at runtime.
ENV HOME=/app \
    LANG=$LANG \
    # Writable tmp directory for releases
    RELEASE_TMP="/run/app"

RUN set -exu ; \
    # Create app dirs
    mkdir -p "/run/app" ; \
    # mkdir -p "/etc/foo" ; \
    # mkdir -p "/var/lib/foo" ; \
    # Make dirs writable by app
    chown -R "nonroot:nonroot" \
        # Needed for RELEASE_TMP
        "/run/app"
        # "/var/lib/foo"


# Create final prod image which gets deployed
FROM prod-base AS prod

# This could be put in a separate target, but it's faster to do it from prod test

# Copy CodeDeploy revision into prod image for publishing later
COPY --from=prod-release --chown="nonroot:nonroot" /revision.zip /revision.zip

# Copy Ansible release into prod image for publishing later
COPY --from=prod-release --chown="nonroot:nonroot" /ansible.zip /ansible.zip

# Setting WORKDIR after USER makes directory be owned by the user.
# Setting it before makes it owned by root, which is more secure.
WORKDIR /app

# When using a startup script, copy to /app/bin
# COPY --link bi[n] ./bin

USER nonroot:nonroot

# Chown files while copying. Running "RUN chown -R app:app /app"
# adds an extra layer which is about 10Mb, a huge difference if the
# app image is around 20Mb.

# TODO: For more security, change specific files to have group read/execute
# permissions while leaving them owned by root

# When using a startup script, unpack release under "/app/current" dir
# WORKDIR /app/current

ARG MIX_ENV
ARG RELEASE

COPY --from=prod-release --chown="nonroot:nonroot" "/app/_build/${MIX_ENV}/rel/${RELEASE}" ./

# App listen ports
EXPOSE 4000

# Prometheus metrics port
EXPOSE 9111
EXPOSE 9568

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

# Wrapper script which runs, e.g., migrations before starting
ENTRYPOINT ["bin/start-docker"]

# Run app in foreground
# CMD ["start"]


# Dev image which mounts code from local filesystem
FROM build-os-deps AS dev
ARG LANG

# Set environment vars used by the app
ENV HOME=/app \
    LANG=$LANG

RUN set -exu ; \
    # Create app dirs
    mkdir -p "/run/app" ; \
    # mkdir -p "/etc/foo" ; \
    # mkdir -p "/var/lib/foo" ; \
    # Make dirs writable by app
    chown -R "nonroot:nonroot" \
        # Needed for RELEASE_TMP
        "/run/app" \
       # "/var/lib/foo"

ARG DEV_PACKAGES

RUN --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
    set -exu ; \
    dnf install -y --nodocs --allowerasing \
        inotify-tools \
        openssh-clients \
        sudo \
        # for chsh
        util-linux-user \
        $DEV_PACKAGES
    # dnf clean all

RUN chsh --shell /bin/bash nonroot


# Copy build artifacts to host
FROM scratch AS artifacts
ARG MIX_ENV
ARG RELEASE

# COPY --from=prod-release "/app/_build/${MIX_ENV}/rel/${RELEASE}" /release
# COPY --from=prod-release /app/_build/${MIX_ENV}/${RELEASE}-*.tar.gz /release
# COPY --from=prod-release "/app/_build/${MIX_ENV}/systemd/lib/systemd/system" /systemd
COPY --from=prod-release /app/priv/static /static


# Default target
FROM prod
