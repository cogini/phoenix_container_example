# Build app
# Deploy using Google Distroless
# See https://github.com/GoogleContainerTools/distroless

ARG BASE_OS=debian

# Specify versions of Erlang, Elixir, and base OS.
# Choose a combination supported by https://hub.docker.com/r/hexpm/elixir/tags

ARG ELIXIR_VER=1.18.3
ARG OTP_VER=27.3.4

# https://docker.debian.net/
# https://hub.docker.com/_/debian
ARG BUILD_OS_VER=bookworm-20250428-slim
ARG PROD_OS_VER=bookworm

# Specify snapshot explicitly to get repeatable builds, see https://snapshot.debian.org/
# The tag without a snapshot (e.g., bullseye-slim) includes the latest snapshot.
# ARG SNAPSHOT_VER=20230612
ARG SNAPSHOT_VER=""
ARG SNAPSHOT_NAME=bookworm

ARG NODE_VER=24.0.1
ARG NODE_MAJOR=24
ARG YARN_VER=1.22.22

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
# https://github.com/GoogleContainerTools/distroless/blob/main/base/README.md
ARG PROD_BASE_IMAGE_NAME=gcr.io/distroless/cc-debian12
# ARG PROD_BASE_IMAGE_TAG=debug-nonroot
# ARG PROD_BASE_IMAGE_TAG=latest
# debug includes busybox, which we need to run Erlang startup scripts
ARG PROD_BASE_IMAGE_TAG=debug

# Intermediate image for files copied to prod
ARG INSTALL_BASE_IMAGE_NAME=${PUBLIC_REGISTRY}${BASE_OS}
ARG INSTALL_BASE_IMAGE_TAG=${PROD_OS_VER}

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
ARG RUNTIME_PACKAGES="libncursesw6"
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

# Configure apt caching for use with BuildKit.
# The default Debian Docker image has special apt config to clear caches,
# but if we are using --mount=type=cache, then we want to keep the files.
# https://github.com/debuerreotype/debuerreotype/blob/master/scripts/debuerreotype-minimizing-config
RUN set -exu ; \
    rm -f /etc/apt/apt.conf.d/docker-clean ; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache ; \
    echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/99use-gzip-compression

ARG SNAPSHOT_VER
ARG SNAPSHOT_NAME
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
    if test -n "$SNAPSHOT_VER" ; then \
        set -exu ; \
        apt-get update -qq ; \
        DEBIAN_FRONTEND=noninteractive \
        apt-get -y install -y -qq --no-install-recommends \
            ca-certificates \
        ; \
        echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} ${SNAPSHOT_NAME} main" > /etc/apt/sources.list ; \
        echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/${SNAPSHOT_VER} ${SNAPSHOT_NAME}-security main" >> /etc/apt/sources.list ; \
        echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} ${SNAPSHOT_NAME}-updates main" >> /etc/apt/sources.list ; \
    fi ; \
    truncate -s 0 /var/log/apt/* ; \
    truncate -s 0 /var/log/dpkg.log


ARG NODE_VER
ARG NODE_MAJOR
ARG RUNTIME_PACKAGES

# Install tools and libraries to build binary libraries
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
    set -exu ; \
    # https://wbk.one/%2Farticle%2F42a272c3%2Fapt-get-build-dep-to-install-build-deps
    # sed -i.bak 's/^# *deb-src/deb-src/g' /etc/apt/sources.list ; \
    apt-get update -qq ; \
    # apt-get -y build-dep python-pil -y ; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install -y -qq --no-install-recommends \
        # Enable installation of packages over https
        apt-transport-https \
        build-essential \
        # Build tools/libraries for Erlang in hexpm/elixir
        # autoconf \
        # dpkg-dev \
        # gcc \
        # gcc-9 \
        # g++ \
        # make \
        # libncurses-dev \
        # unixodbc-dev \
        # libssl-dev \
        # libsctp-dev \
        ca-certificates \
        cmake \
        curl \
        git \
        gnupg \
        gnupg-agent \
        jq \
        # software-properties-common \
        locales \
        lsb-release \
        openssh-client \
        wget \
        zip \
        $RUNTIME_PACKAGES \
    ; \
    # Support keyrings for apt repositories
    mkdir -p -m 755 /etc/apt/keyrings ; \
    # Install nodejs from nodesource.com repo
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg ; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list ; \
    #
    # Install node using n
    # curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o /usr/local/bin/n ; \
    # chmod +x /usr/local/bin/n ; \
    # # Install lts version of node
    # # n lts ; \
    # # Install specific version of node
    # n "$NODE_VER" ; \
    # rm /usr/local/bin/n ; \
    #
    # Install yarn from repo
    # curl -sL --ciphers ECDHE-RSA-AES128-GCM-SHA256 https://dl.yarnpkg.com/debian/pubkey.gpg -o /etc/apt/trusted.gpg.d/yarn.asc ; \
    # echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list ; \
    # printf "Package: *\nPin: release o=dl.yarnpkg.com\nPin-Priority: 500\n" | tee /etc/apt/preferences.d/yarn.pref ; \
    #
    # Install GitHub CLI
    # wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg ; \
    # chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg ; \
    # echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list ; \
    #
    # Install Trivy
    # curl -sL https://aquasecurity.github.io/trivy-repo/deb/public.key -o /etc/apt/trusted.gpg.d/trivy.asc ; \
    # printf "deb https://aquasecurity.github.io/trivy-repo/deb %s main" "$(lsb_release -sc)" | tee -a /etc/apt/sources.list.d/trivy.list ; \
    #
    # Install Grype
    # curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin ; \
    #
    # Install latest PostgreSQL client library from postgres.org repo
    # curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /etc/apt/trusted.gpg.d/postgresql-ACCC4CF8.asc ; \
    # echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list ; \
    # echo "Package: *\nPin: release o=apt.postgresql.org\nPin-Priority: 500\n" | tee /etc/apt/preferences.d/pgdg.pref ; \
    #
    # Install Microsoft ODBC Driver for SQL Server
    # curl -sL https://packages.microsoft.com/keys/microsoft.asc -o /etc/apt/trusted.gpg.d/microsoft.asc ; \
    # curl -s https://packages.microsoft.com/config/debian/11/prod.list -o /etc/apt/sources.list.d/mssql-release.list ; \
    # export ACCEPT_EULA=Y ; \
    #
    # Install specific version of mysql from MySQL repo
    # mysql-5.7 is not available for Debian Bullseye (11), only Buster (10)
    # The key id comes from this page: https://dev.mysql.com/doc/refman/5.7/en/checking-gpg-signature.html
    # # apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3A79BD29
    # #   gpg: key 3A79BD29: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>" imported
    # export APT_KEY='859BE8D7C586F538430B19C2467B942D3A79BD29' ; \
    # export GPGHOME="$(mktemp -d)" ; \
    # gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$APT_KEY" ; \
    # gpg --batch --export "$APT_KEY" > /etc/apt/keyrings/mysql.gpg ; \
    # gpgconf --kill all ; \
    # rm -rf "$GPGHOME" ; \
    # rm -rf "${HOME}/.gnupg" ; \
    # echo "deb [ signed-by=/etc/apt/keyrings/mysql.gpg ] http://repo.mysql.com/apt/debian/ $(lsb_release -sc) mysql-5.7" | tee /etc/apt/sources.list.d/mysql.list ; \
    # echo "Package: *\nPin: release o=repo.mysql.com\nPin-Priority: 500\n" | tee /etc/apt/preferences.d/mysql.pref ; \
    apt-get update -qq ; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install -y -qq --no-install-recommends \
        # gh \
        nodejs \
        # trivy \
        # yarn \
        # yarnpkg \
        # libpq-dev postgresql-client \
        # msodbcsql17 \
        # libmysqlclient-dev mysql-client \
    ; \
    # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
    # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
    # Remove packages installed temporarily. Removes everything related to
    # packages, including the configuration files, and packages
    # automatically installed because a package required them but, with the
    # other packages removed, are no longer needed.
    # apt-get purge -y --auto-remove curl ; \
    # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
    # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
    # Delete local repository of retrieved package files in /var/cache/apt/archives
    # This is handled automatically by /etc/apt/apt.conf.d/docker-clean
    # Use this if not running --mount=type=cache.
    # apt-get clean ; \
    # Delete info on installed packages. This saves some space, but it can
    # be useful to have them as a record of what was installed, e.g. for auditing.
    # rm -rf /var/lib/dpkg ; \
    # Delete debconf data files to save some space
    # rm -rf /var/cache/debconf ; \
    # Delete index of available files from apt-get update
    # Use this if not running --mount=type=cache.
    # rm -rf /var/lib/apt/lists/*
    # Clear logs of installed packages
    truncate -s 0 /var/log/apt/* ; \
    truncate -s 0 /var/log/dpkg.log

ARG LANG
RUN set -exu ; \
    # Generate locales specified in /etc/locale.gen
    sed -i "/# ${LANG}/s/^# //g" /etc/locale.gen ; \
    cat /etc/locale.gen | grep "${LANG}" ; \
    locale-gen ; \
    localedef --list-archive ; \
    ls -l /usr/lib/locale/

RUN set -ex ; corepack enable ; corepack enable npm ;
    # npm install -g yarn


# Get Elixir deps
FROM build-os-deps AS build-deps-get
ARG APP_DIR
ENV HOME=$APP_DIR

WORKDIR $APP_DIR

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
ARG APP_DIR

WORKDIR $APP_DIR

ARG MIX_ENV
# COPY --link config ./config
COPY --link config/config.exs "config/${MIX_ENV}.exs" ./config/

# Build assets
RUN mkdir -p ./assets

# Install JavaScript deps
COPY --link assets/package.jso[n] assets/package-lock.jso[n] assets/yarn.loc[k] assets/brunch-config.j[s] ./assets/

WORKDIR ${APP_DIR}/assets

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

WORKDIR $APP_DIR

# Compile deps separately from the application for better Docker caching.
# Doing "mix 'do' compile, assets.deploy" in a single stage is worse
# because a single line of code changed causes a complete recompile.

COPY --link .env.pro[d] ./

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
# Configure apt caching for use with BuildKit.
# The default Debian Docker image has special config to clear caches.
# If we are using --mount=type=cache, then we want it to preserve cached files.
RUN set -exu ; \
    rm -f /etc/apt/apt.conf.d/docker-clean ; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache ; \
    echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/99use-gzip-compression

ARG SNAPSHOT_VER
ARG SNAPSHOT_NAME

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
    if test -n "$SNAPSHOT_VER" ; then \
        set -exu ; \
        apt-get update -qq ; \
        DEBIAN_FRONTEND=noninteractive \
        apt-get -y install -y -qq --no-install-recommends \
            ca-certificates \
        ; \
        echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} ${SNAPSHOT_NAME} main" > /etc/apt/sources.list ; \
        echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/${SNAPSHOT_VER} ${SNAPSHOT_NAME}-security main" >> /etc/apt/sources.list ; \
        echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} ${SNAPSHOT_NAME}-updates main" >> /etc/apt/sources.list ; \
    fi ; \
    truncate -s 0 /var/log/apt/* ; \
    truncate -s 0 /var/log/dpkg.log

ARG RUNTIME_PACKAGES

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
    set -exu ; \
    apt-get update -qq ; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install -y -qq --no-install-recommends \
        # Enable installation of packages over https
        # apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        # software-properties-common \
        gnupg \
        unzip \
        # jq \
        lsb-release \
        # Needed by Erlang VM
        libncursesw6 \
        libtinfo6 \
        # Additional libs
        libstdc++6 \
        libgcc-s1 \
        locales \
        $RUNTIME_PACKAGES \
    ; \
    # Remove packages installed temporarily. Removes everything related to
    # packages, including the configuration files, and packages
    # automatically installed because a package required them but, with the
    # other packages removed, are no longer needed.
    # apt-get purge -y --auto-remove curl ; \
    # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
    # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
    # Delete local repository of retrieved package files in /var/cache/apt/archives
    # This is handled automatically by /etc/apt/apt.conf.d/docker-clean
    # Use this if not running --mount=type=cache.
    # apt-get clean ; \
    # Delete info on installed packages. This saves some space, but it can
    # be useful to have them as a record of what was installed, e.g. for auditing.
    # rm -rf /var/lib/dpkg ; \
    # Delete debconf data files to save some space
    # rm -rf /var/cache/debconf ; \
    # Delete index of available files from apt-get update
    # Use this if not running --mount=type=cache.
    # rm -rf /var/lib/apt/lists/*
    # Clear logs of installed packages
    truncate -s 0 /var/log/apt/* ; \
    truncate -s 0 /var/log/dpkg.log

ARG LANG
RUN set -exu ; \
    # Generate locales specified in /etc/locale.gen
    sed -i "/# ${LANG}/s/^# //g" /etc/locale.gen ; \
    grep -v '^#' /etc/locale.gen ; \
    locale-gen ; \
    localedef --list-archive ; \
    ls -l /usr/lib/locale/

# Stage files for copying into final image.
RUN set -ex ; \
    mkdir -p /stage/var/lib/dpkg/status.d ; \
    mkdir -p /stage/bin ; \
    touch /stage/bin/make-symlinks.sh ; \
    # Minimal files needed for Erlang VM
    # https://packages.debian.org/bookworm/arm64/libncursesw6
    # https://packages.debian.org/bookworm/arm64/libtinfo6
    # for pkg in libncursesw6 libtinfo6 jq libjq1 libonig5 ; do \
    for pkg in libncursesw6 libtinfo6 ; do \
        # Create dpkg status files for use by security scanners like Trivy
        awk "BEGIN{RS=\"\"; FS=\"\n\"}/^Package: ${pkg}/" /var/lib/dpkg/status > "/stage/var/lib/dpkg/status.d/${pkg}" ; \
        for file in $(dpkg-query --listfiles "${pkg}" | sort -u) ; do \
            if [ -f "$file" ] ; then \
                dir=$(dirname "$file") ; \
                mkdir -p "/stage${dir}" ; \
                if [ -L "$file" ] ; then \
                    target=$(readlink "$file") ; \
                    echo "ln -v -s ${dir}/${target} ${file}" >> /stage/bin/make-symlinks.sh ; \
                else \
                    cp -v "$file" "/stage${file}" ; \
                fi ; \
                md5sum $file >> "/stage/var/lib/dpkg/status.d/${pkg}.md5sums" ; \
            fi ; \
        done ; \
    done ; \
    cat /stage/bin/make-symlinks.sh ; \
    find /stage -type f -print

# These packages are part of the Google distroless/cc image
# libgcc-s1
# /lib/$(uname -m)-linux-gnu/libgcc_s.so.1
# libstdc++6
# /usr/lib/$(uname -m)-linux-gnu/libstdc++.so.6.0.28


# Create base image for prod with everything but the code release
FROM ${PROD_BASE_IMAGE_NAME}:${PROD_BASE_IMAGE_TAG} AS prod-base
ARG APP_NAME
ARG APP_DIR
ARG APP_GROUP
ARG APP_GROUP_ID
ARG APP_USER
ARG APP_USER_ID

# User and group are created in the Google Distroless base image (nonroot:nonroot)

# Default environment vars:
# SHLVL=1
# SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/busybox

# Link busybox shell to standard path
RUN ["/busybox/sh", "-c", "ln -s /busybox/sh /bin/sh"]

# Copy staged files
COPY --from=prod-install ["/stage", "/"]

# Make symlinks for files copied from prod-install stage
RUN if test -s /bin/make-symlinks.sh ; then \
        /bin/sh /bin/make-symlinks.sh ; \
    fi

ARG LANG
COPY --link --from=prod-install /usr/lib/locale/locale-archive /usr/lib/locale/

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

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
    set -exu ; \
    apt-get update -qq ; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install -y -qq --no-install-recommends \
        inotify-tools \
        ssh \
        sudo \
        $DEV_PACKAGES \
    ; \
    # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
    # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
    # Remove packages installed temporarily. Removes everything related to
    # packages, including the configuration files, and packages
    # automatically installed because a package required them but, with the
    # other packages removed, are no longer needed.
    # apt-get purge -y --auto-remove curl ; \
    # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
    # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
    # Delete local repository of retrieved package files in /var/cache/apt/archives
    # This is handled automatically by /etc/apt/apt.conf.d/docker-clean
    # Use this if not running --mount=type=cache.
    # apt-get clean ; \
    # Delete info on installed packages. This saves some space, but it can
    # be useful to have them as a record of what was installed, e.g. for auditing.
    # rm -rf /var/lib/dpkg ; \
    # Delete debconf data files to save some space
    # rm -rf /var/cache/debconf ; \
    # Delete index of available files from apt-get update
    # Use this if not running --mount=type=cache.
    # rm -rf /var/lib/apt/lists/*
    # Clear logs of installed packages
    truncate -s 0 /var/log/apt/* ; \
    truncate -s 0 /var/log/dpkg.log

ARG LANG
RUN set -exu ; \
    # Generate locales specified in /etc/locale.gen
    sed -i "/# ${LANG}/s/^# //g" /etc/locale.gen ; \
    locale-gen ; \
    localedef --list-archive ; \
    ls -l /usr/lib/locale/

# Set environment vars used by the app
ENV HOME=$APP_DIR \
    LANG=$LANG

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
