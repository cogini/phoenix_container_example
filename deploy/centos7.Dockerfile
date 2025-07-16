# Build app
# Deploy using CentOS

ARG BASE_OS=centos

# Specify versions of Erlang, Elixir, and base OS.
# Choose a combination supported by https://hub.docker.com/r/hexpm/elixir/tags

ARG ELIXIR_VER=1.18.3
ARG OTP_VER=27.3.3

# https://hub.docker.com/_/centos
ARG BUILD_OS_VER=8
ARG PROD_OS_VER=8

# Newer binary releases of nodejs require a newer version of glibc not
# available in CentOS 7, so we are stuck with 14.
ARG NODE_MAJOR=14
ARG NODE_VER=14.21.3
ARG YARN_VER=1.22.22

ARG REBAR_VER=3.24.0
ARG HEX_VER=2.2.1

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
ARG BUILD_BASE_IMAGE_TAG=7.9.2009

# Base for final prod image
ARG PROD_BASE_IMAGE_NAME=${PUBLIC_REGISTRY}${BASE_OS}
# ARG PROD_BASE_IMAGE_TAG=$PROD_OS_VER
ARG PROD_BASE_IMAGE_TAG=7.9.2009

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
# These variables must always have something defined
ARG RUNTIME_PACKAGES="ca-certificates"
ARG DEV_PACKAGES="inotify-tools"


# Create build base image with OS dependencies
FROM ${BUILD_BASE_IMAGE_NAME}:${BUILD_BASE_IMAGE_TAG} AS build-os-deps
ARG APP_DIR
ARG APP_GROUP
ARG APP_GROUP_ID
ARG APP_USER
ARG APP_USER_ID

# Create OS user and group to run app under
RUN if ! grep -q "$APP_USER" /etc/passwd; \
    then groupadd -g "$APP_GROUP_ID" "$APP_GROUP" && \
    useradd -l -u "$APP_USER_ID" -g "$APP_GROUP" -d "$APP_DIR" -s /usr/sbin/nologin "$APP_USER" && \
    rm -f /var/log/lastlog && rm -f /var/log/faillog; fi

# RUN cat /etc/redhat-release

# Fix repositories to use Centos vault
RUN --mount=type=cache,id=yum-cache,target=/var/cache/yum,sharing=locked \
    set -ex ; \
    sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/*.repo ; \
    # sed -i -e '/^mirrorlist/d;/^#baseurl=/{s,^#,,;s,/mirror,/vault,;}' /etc/yum.repos.d/CentOS*.repo
    yum clean all ; \
    yum makecache ; \
    yum repolist ; \
    yum install -y epel-release deltarpm ; \
    yum install -y centos-release-scl ; \
    ls -l /etc/yum.repos.d/ ; \
    # installing centos-release-scl adds the Software Collections repo to Yum's configuration,
    # so the following replacement should be used for downloading from Centos vault
    # sed -i 's|mirror.centos.org/centos|vault.centos.org/altarch|g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/*.repo ; \
    for i in `ls /etc/yum.repos.d/*.repo`; do \
        echo ; \
        echo "# >>>>> $i"; \
        cat "$i"; \
    done ; \
    yum update -y

ARG RUNTIME_PACKAGES

# Install tools and libraries to build binary libraries
RUN --mount=type=cache,id=yum-cache,target=/var/cache/yum,sharing=locked \
    set -ex ; \
    yum makecache ; \
    # yum install -y epel-release deltarpm ; \
    # yum install -y cmake centos-release-scl ; \
    # yum groupinstall -y 'Development Tools' ; \
    # yum groupinstall -y 'Development Tools' 'C Development Tools and Libraries' ; \
    yum install -y \
        ca-certificates \
        cmake \
        # cmake3 \
        curl \
        git \
        glibc-langpack-en \
        gpg \
        make \
        # useradd and groupadd
        shadow-utils \
        unzip \
        wget \
        which \
        zip \
     ; \
    # devtoolset-10 is the latest supported by arm64
    # https://forums.centos.org/viewtopic.php?t=80435
    # https://serverfault.com/questions/709433/install-a-newer-version-of-git-on-centos-7
    yum install -y devtoolset-10-toolchain devtoolset-10-gcc-c++ ; \
    yum install -y rh-git227 ; \
    # Use cmake3
    alternatives --install /usr/local/bin/cmake cmake /usr/bin/cmake 10 \
        --slave /usr/local/bin/ctest ctest /usr/bin/ctest \
        --slave /usr/local/bin/cpack cpack /usr/bin/cpack \
        --slave /usr/local/bin/ccmake ccmake /usr/bin/ccmake \
        --family cmake ; \
    alternatives --install /usr/local/bin/cmake cmake /usr/bin/cmake3 20 \
        --slave /usr/local/bin/ctest ctest /usr/bin/ctest3 \
        --slave /usr/local/bin/cpack cpack /usr/bin/cpack3 \
        --slave /usr/local/bin/ccmake ccmake /usr/bin/ccmake3 \
        --family cmake ; \
    # cat /opt/rh/devtoolset-10/enable ; \
    source /opt/rh/devtoolset-10/enable ; \
    source /opt/rh/rh-git227/enable ; \
    # http://erlang.org/doc/installation_guide/INSTALL.html#required-utilities
    # https://github.com/asdf-vm/asdf-erlang
    # bin/build-install-asdf-deps-centos ; \
    # https://github.com/asdf-vm/asdf-erlang/issues/206
    # rpm --eval '%{_arch}' ; \
    # https://github.com/nodejs/node/blob/main/BUILDING.md#building-nodejs-on-supported-platforms
    yum install -y \
        autoconf \
        automake \
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
        # python3 \
        # python3-pip \
        # SCL python
        # rh-python38 \
        # https://github.com/pyenv/pyenv/wiki#suggested-build-environment
        # patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel tcl-devel tk-devel libffi-devel xz-devel \
        # compat-openssl11-devel \
        openssl-devel \
        # openssl11-devel \
        readline-devel \
        sqlite-devel \
        unixODBC-devel \
        # yum-utils \
        # wxGTK wxGTK-devel wxGTK-gl wxGTK-media
        wxGTK3 wxGTK3-devel wxGTK3-gl wxGTK3-media
        # wxBase3 \
        # erlang-odbc
        # $RUNTIME_PACKAGES \
    # ; \
    # yum clean all
    # yum clean all ; rm -rf /var/cache/yum

# RUN localedef -i en_US -f UTF-8 en_US.UTF-8

# Use latest CA certs from Mozilla for hex
# https://curl.se/docs/caextract.html
# https://stackoverflow.com/questions/37043442/how-to-add-certificate-authority-file-in-centos-7
RUN set -ex ; \
    curl https://curl.se/ca/cacert.pem -o /etc/pki/ca-trust/source/anchors/ca-bundle.crt ; \
    update-ca-trust

# https://hexdocs.pm/mix/Mix.html
ENV HEX_CACERTS_PATH=/etc/pki/ca-trust/source/anchors/ca-bundle.crt
ENV ERL_AFLAGS="-public_key cacerts_path '\"/etc/pki/ca-trust/source/anchors/ca-bundle.crt\"'"

ENV HOME=$APP_DIR

WORKDIR $APP_DIR

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
# Python is a dependency to build nodejs from source
# Compile separately because it is slow
# RUN set -ex ; \
#     export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH" ; \
#     export CFLAGS="$CFLAGS -O2 -g $(pkg-config --cflags openssl11)" ; \
#     export LDFLAGS="$LDFLAGS $(pkg-config --libs openssl11)" ; \
#     source /opt/rh/devtoolset-10/enable ; \
#     source /opt/rh/rh-git227/enable ; \
#     # yum list rh-python3\* ; \
#     # source /opt/rh/rh-python38/enable ; \
#     export TCLTK_LIBS="-ltk8.5 -ltkstub8.5 -ltcl8.5" ; \
#     export PYENV_DEBUG=1 ; \
#     asdf install python 3.12.11 ;

# Compile separately because it is slow
# RUN set -ex ; \
#     export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH" ; \
#     export CFLAGS="$CFLAGS -O2 -g $(pkg-config --cflags openssl11)" ; \
#     export LDFLAGS="$LDFLAGS $(pkg-config --libs openssl11)" ; \
#     source /opt/rh/devtoolset-10/enable ; \
#     source /opt/rh/rh-git227/enable ; \
#     # https://github.com/asdf-vm/asdf-nodejs
#     # https://github.com/nodenv/node-build#custom-build-configuration
#     # Force compilation from source, as binary release does not work on CentOS 7
#     export ASDF_NODEJS_FORCE_COMPILE=1 ; \
#     export ASDF_NODEJS_VERBOSE_INSTALL=1 ; \
#     export MAKE_OPTS="-j$(getconf _NPROCESSORS_ONLN)" ; \
#     # export ASDF_NODEJS_CONCURRENCY="$(getconf _NPROCESSORS_ONLN)" ; \
#     asdf install nodejs ;

RUN set -ex ; \
    export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH" ; \
    source /opt/rh/devtoolset-10/enable ; \
    source /opt/rh/rh-git227/enable ; \
    # Install Erlang Solutions binary
    # bin/build-install-deps-centos ; \
    # Erlang build scripts expect the name to be wx-config
    ln -s /usr/bin/wx-config-3.0 /usr/bin/wx-config ; \
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
    #   bin/build-install-deps-centos; \
    # else \
    #   # Install using asdf
    #   # bin/build-install-asdf
    #   asdf install erlang; \
    # fi ; \
    asdf reshim ; \
    erl -version ; \
    elixir -v ; \
    node -v


# Get Elixir deps
FROM build-os-deps AS build-deps-get
ARG LANG

ARG APP_DIR
ENV HOME=$APP_DIR

RUN env

WORKDIR $APP_DIR

# This mix task fails with a TLS error, so download and install manually
# RUN mix 'do' local.rebar --force, local.hex --force

ARG HEX_VER
ARG REBAR_VER

# TLS error downloading hex and rebar, so download them separately
RUN set -ex ; \
    export MIX_DEBUG=1 ; \
    curl -o /tmp/hex.ez "https://builds.hex.pm/installs/1.16.0/hex-${HEX_VER}.ez" ; \
    mix archive.install --force /tmp/hex.ez ; \
    mix local.rebar rebar3 /app/.asdf/installs/rebar/${REBAR_VER}/bin/rebar3

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
ARG APP_DIR

ENV MIX_ENV=test

WORKDIR $APP_DIR

# Postman tests
# RUN npm install -g newman
# RUN npm install -g newman-reporter-junitfull
COPY --link Postma[n] ./Postman

# COPY --link config ./config
COPY --link config/config.exs "config/${MIX_ENV}.exs" ./config/

# Compile deps separately from app, improving Docker caching
RUN set -ex ; \
    source /opt/rh/devtoolset-10/enable ; \
    source /opt/rh/rh-git227/enable ; \
    mix deps.compile

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
ARG APP_DIR

WORKDIR $APP_DIR

# Build assets
RUN mkdir -p ./assets

# Install JavaScript deps
COPY --link assets/package.jso[n] assets/package-lock.jso[n] assets/yarn.loc[k] assets/brunch-config.j[s] ./assets/

WORKDIR ${APP_DIR}/assets

# Install JavaScript dependencies
RUN --mount=type=cache,target=~/.npm,sharing=locked \
    # corepack enable ; corepack enable npm ; \
    # yarn --cwd ./assets install --prod
    # yarn install --prod
    # pnpm install --prod
    npm install
    # npm run deploy
    # npm --prefer-offline --no-audit --progress=false --loglevel=error ci
    # node node_modules/brunch/bin/brunch build
    # node node_modules/webpack/bin/webpack.js --mode production

WORKDIR $APP_DIR

# Compile deps separately from the application for better Docker caching.
# Doing "mix 'do' compile, assets.deploy" in a single stage is worse
# because a single line of code changed causes a complete recompile.

COPY --link .env.pro[d] ./

ARG MIX_ENV
# COPY --link config ./config
COPY --link config/config.exs "config/${MIX_ENV}.exs" ./config/

# Load environment vars when compiling
RUN if test -f .env.prod ; then set -a ; . ./.env.prod ; set +a ; env ; fi ; \
    source /opt/rh/devtoolset-10/enable ; \
    source /opt/rh/rh-git227/enable ; \
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
    source /opt/rh/devtoolset-10/enable ; \
    source /opt/rh/rh-git227/enable ; \
    # mix compile --warnings-as-errors
    mix compile

# Downloading is broken on CentOS 7, so download manually
# RUN mix assets.setup

# Use latest CA certs from Mozilla for hex
# https://curl.se/docs/caextract.html
# https://stackoverflow.com/questions/37043442/how-to-add-certificate-authority-file-in-centos-7
RUN set -ex ; \
    curl https://curl.se/ca/cacert.pem -o /etc/pki/ca-trust/source/anchors/ca-bundle.crt ; \
    update-ca-trust

# https://hexdocs.pm/mix/Mix.html
ENV HEX_CACERTS_PATH=/etc/pki/ca-trust/source/anchors/ca-bundle.crt
ENV ERL_AFLAGS="-public_key cacerts_path '\"/etc/pki/ca-trust/source/anchors/ca-bundle.crt\"'"

RUN set -ex ; \
    curl -v --location https://github.com/tailwindlabs/tailwindcss/releases/download/v3.3.2/tailwindcss-linux-x64 -o /app/_build/tailwind-linux-x64 ; \
    chmod +x /app/_build/tailwind-linux-x64 ;

RUN mix assets.deploy

# Build release
COPY --link config/runtime.exs ./config/

COPY --link rel ./rel

# Generate systemd and deploy scripts
# RUN mix do systemd.init, systemd.generate, deploy.init, deploy.generate

ARG RELEASE
RUN mix release "$RELEASE"

# Create revision for CodeDeploy
# WORKDIR /revision
# COPY appspec.yml ./
# RUN set -exu ; \
#     mkdir -p etc bin systemd ; \
#     chmod +x /app/bin/* ; \
#     cp /app/bin/* ./bin/ ; \
#     cp /app/_build/${MIX_ENV}/systemd/lib/systemd/system/* ./systemd/ ; \
#     cp /app/_build/${MIX_ENV}/${RELEASE}-*.tar.gz "./${RELEASE}.tar.gz" ; \
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
#     mkdir -p bin ; \
#     cp /app/bin/* ./bin/ ; \
#     chmod +x ./bin/* ; \
#     cp /app/_build/${MIX_ENV}/${RELEASE}-*.tar.gz _build/${MIX_ENV}/ ; \
#     zip -r /ansible.zip . ; \
#     rm -rf /ansible/*


# Create staging image for files which are copied into final prod image
FROM ${INSTALL_BASE_IMAGE_NAME}:${INSTALL_BASE_IMAGE_TAG} AS prod-install
ARG LANG

# https://groups.google.com/g/cloudlab-users/c/Re6Jg7oya68?pli=1

ARG RUNTIME_PACKAGES

RUN --mount=type=cache,id=yum-cache,target=/var/cache/yum,sharing=locked \
    set -exu ; \
    sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/*.repo ; \
    # sed -i -e '/^mirrorlist/d;/^#baseurl=/{s,^#,,;s,/mirror,/vault,;}' /etc/yum.repos.d/CentOS*.repo
    yum clean all ; \
    yum makecache ; \
    yum repolist ; \
    yum install -y epel-release deltarpm ; \
    yum install -y centos-release-scl ; \
    # ls -l /etc/yum.repos.d/ ; \
    # installing centos-release-scl adds the Software Collections repo to Yum's configuration,
    # so the following replacement should be used for downloading from Centos vault
    # sed -i 's|mirror.centos.org/centos|vault.centos.org/altarch|g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/*.repo ; \
    yum update -y

RUN --mount=type=cache,id=yum-cache,target=/var/cache/yum,sharing=locked \
    set -exu ; \
    yum install -y \
        ca-certificates \
        curl \
        gnupg-agent \
        # software-properties-common \
        glibc-langpack-en \
        gpg \
        unzip \
        # jq \
        lsb-release \
        # Needed by Erlang VM
        libtinfo6 \
        # Additional libs
        libstdc++6 \
        libgcc-s1 \
        locales \
        $RUNTIME_PACKAGES \
    ;
    # yum clean all
    # yum clean all ; rm -rf /var/cache/yum

    RUN yum list glibc-langpack-\*

# Creating minimal CentOS docker image from scratch
# https://gist.github.com/silveraid/e6bdf78441c731a30a66fc6adca6f4b5
# https://www.mankier.com/8/microdnf
# https://git.rockylinux.org/rocky/images/-/blob/main/base/scripts/build-container-rootfs.sh


# Create base image for prod with everything but the code release
FROM ${PROD_BASE_IMAGE_NAME}:${PROD_BASE_IMAGE_TAG} AS prod-base
ARG APP_NAME
ARG APP_DIR
ARG APP_GROUP
ARG APP_GROUP_ID
ARG APP_USER
ARG APP_USER_ID

# Create OS user and group to run app under
RUN if ! grep -q "$APP_USER" /etc/passwd; \
    then groupadd -g "$APP_GROUP_ID" "$APP_GROUP" && \
    useradd -l -u "$APP_USER_ID" -g "$APP_GROUP" -d "$APP_DIR" -s /usr/sbin/nologin "$APP_USER" && \
    rm -f /var/log/lastlog && rm -f /var/log/faillog; fi

ARG RUNTIME_PACKAGES

RUN --mount=type=cache,id=yum-cache,target=/var/cache/yum,sharing=locked \
    set -ex ; \
    sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/*.repo ; \
    # sed -i -e '/^mirrorlist/d;/^#baseurl=/{s,^#,,;s,/mirror,/vault,;}' /etc/yum.repos.d/CentOS*.repo
    yum clean all ; \
    yum makecache ; \
    yum repolist ; \
    yum install -y epel-release deltarpm ; \
    yum install -y centos-release-scl ; \
    ls -l /etc/yum.repos.d/ ; \
    # installing centos-release-scl adds the Software Collections repo to Yum's configuration,
    # so the following replacement should be used for downloading from Centos vault
    # sed -i 's|mirror.centos.org/centos|vault.centos.org/altarch|g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/*.repo ; \
    sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/*.repo ; \
    yum update -y

RUN --mount=type=cache,id=yum-cache,target=/var/cache/yum,sharing=locked \
    set -exu ; \
    # yum install -y epel-release deltarpm ; \
    # yum update -y ; \
    yum install -y \
        # Enable the app to make outbound SSL calls.
        ca-certificates \
        # Run health checks and get ECS metadata
        # curl \
        glibc-langpack-en \
        jq \
        # useradd and groupadd
        shadow-utils \
        wget \
        # openssl11-libs \
        $RUNTIME_PACKAGES
    # yum clean all
    # yum clean all ; rm -rf /var/cache/yum

ARG LANG

# Set environment vars that do not change. Secrets like SECRET_KEY_BASE and
# environment-specific config such as DATABASE_URL are set at runtime.
ENV HOME=$APP_DIR \
    LANG=$LANG \
    # Writable tmp directory for releases
    RELEASE_TMP="/run/${APP_NAME}"

RUN set -exu ; \
    # Create app dirs
    mkdir -p "/run/${APP_NAME}" ; \
    # mkdir -p "/etc/foo" ; \
    # mkdir -p "/var/lib/foo" ; \
    # Make dirs writable by app
    chown -R "${APP_USER}:${APP_GROUP}" \
        # Needed for RELEASE_TMP
        "/run/${APP_NAME}"
        # "/var/lib/foo"


# Create final prod image which gets deployed
FROM prod-base AS prod
ARG APP_DIR
ARG APP_USER
ARG APP_GROUP

# This could be put in a separate target, but it's faster to do it from prod test

# Copy CodeDeploy revision into prod image for publishing later
# COPY --from=prod-release --chown="$APP_USER:$APP_GROUP" /revision.zip /revision.zip

# Copy Ansible release into prod image for publishing later
# COPY --from=prod-release --chown="$APP_USER:$APP_GROUP" /ansible.zip /ansible.zip

# USER $APP_USER:$APP_GROUP

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

ARG MIX_ENV
ARG RELEASE

COPY --from=prod-release --chown="$APP_USER:$APP_GROUP" "/app/_build/${MIX_ENV}/rel/${RELEASE}" ./

ARG APP_PORT
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

# Set environment vars used by the app
ENV HOME=$APP_DIR \
    LANG=$LANG

RUN set -exu ; \
    # Create app dirs
    mkdir -p "/run/${APP_NAME}" ; \
    # mkdir -p "/etc/foo" ; \
    # mkdir -p "/var/lib/foo" ; \
    # Make dirs writable by app
    chown -R "${APP_USER}:${APP_GROUP}" \
        # Needed for RELEASE_TMP
        "/run/${APP_NAME}"
       # "/var/lib/foo"

ARG DEV_PACKAGES

RUN --mount=type=cache,id=yum-cache,target=/var/cache/yum,sharing=locked \
    set -exu ; \
    yum install -y \
        inotify-tools \
        ssh \
        sudo \
        # for chsh
        util-linux-user \
        $DEV_PACKAGES \
    ;
    # yum clean all
    # yum clean all ; rm -rf /var/cache/yum

RUN chsh --shell /bin/bash "$APP_USER"


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
