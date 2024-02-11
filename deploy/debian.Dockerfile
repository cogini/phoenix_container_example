# Build app
# Deploy using Debian

ARG BASE_OS=debian

# Specify versions of Erlang, Elixir, and base OS.
# Choose a combination supported by https://hub.docker.com/r/hexpm/elixir/tags

ARG ELIXIR_VER=1.15.7
ARG OTP_VER=26.1.2

# https://docker.debian.net/
# https://hub.docker.com/_/debian
# Specify snapshot explicitly to get repeatable builds, see https://snapshot.debian.org/
# The tag without a snapshot (e.g., bullseye-slim) includes the latest snapshot.
ARG BUILD_OS_VER=bullseye-20230612-slim
ARG PROD_OS_VER=bullseye-20230612-slim

# ARG SNAPSHOT_VER=20230612
ARG SNAPSHOT_VER=""

# ARG NODE_VER=16.14.1
ARG NODE_VER=lts
ARG NODE_MAJOR=20

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
    ARG SNAPSHOT_VER
    ARG RUNTIME_PACKAGES
    ARG NODE_MAJOR

    ARG APP_DIR
    ARG APP_GROUP
    ARG APP_GROUP_ID
    ARG APP_USER
    ARG APP_USER_ID

    # Create OS user and group to run app under
    RUN if ! grep -q "$APP_USER" /etc/passwd; \
        then groupadd -g "$APP_GROUP_ID" "$APP_GROUP" && \
        useradd -l -u "$APP_USER_ID" -g "$APP_GROUP" -s /usr/sbin/nologin "$APP_USER" && \
        rm /var/log/lastlog && rm /var/log/faillog; fi

    # Configure apt caching for use with BuildKit.
    # The default Debian Docker image has special apt config to clear caches,
    # but if we are using --mount=type=cache, then we want to keep the files.
    # https://github.com/debuerreotype/debuerreotype/blob/master/scripts/debuerreotype-minimizing-config
    RUN set -exu && \
        rm -f /etc/apt/apt.conf.d/docker-clean && \
        echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
        echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/99use-gzip-compression

    RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
        --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
        if test -n "$SNAPSHOT_VER" ; then \
            set -exu && \
            apt-get update -qq && \
            DEBIAN_FRONTEND=noninteractive \
            apt-get -y install -y -qq --no-install-recommends \
                ca-certificates \
            && \
            echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} bullseye main" > /etc/apt/sources.list && \
            echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/${SNAPSHOT_VER} bullseye-security main" >> /etc/apt/sources.list && \
            echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} bullseye-updates main" >> /etc/apt/sources.list; \
        fi

    # Install tools and libraries to build binary libraries
    # Not necessary for a minimal Phoenix app, but likely needed
    RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
        --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
        set -exu && \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive \
        apt-get -y install -y -qq --no-install-recommends \
            # Enable installation of packages over https
            apt-transport-https \
            build-essential \
            # Enable app to make outbound SSL calls
            ca-certificates \
            curl \
            git \
            gnupg \
            gnupg-agent \
            jq \
            # software-properties-common \
            locales \
            lsb-release \
            openssh-client \
            # Support ssl in container, as opposed to load balancer
            openssl \
            # Install default nodejs
            # nodejs \
            # Install default Postgres
            # libpq-dev \
            # postgresql-client \
            # $RUNTIME_PACKAGES \
        && \
        locale-gen && \
        mkdir -p /etc/apt/keyrings && \
        # Install nodejs from nodesource.com
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
        # Install node using n
        # curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o /usr/local/bin/n && \
        # chmod +x /usr/local/bin/n && \
        # # Install lts version of node
        # # n lts && \
        # # Install specific version of node
        # n "$NODE_VER" && \
        # rm /usr/local/bin/n && \
        # Install yarn from repo
        curl -sL --ciphers ECDHE-RSA-AES128-GCM-SHA256 https://dl.yarnpkg.com/debian/pubkey.gpg -o /etc/apt/trusted.gpg.d/yarn.asc && \
        echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
        printf "Package: *\nPin: release o=dl.yarnpkg.com\nPin-Priority: 500\n" | tee /etc/apt/preferences.d/yarn.pref && \
        # Install Trivy
        # curl -sL https://aquasecurity.github.io/trivy-repo/deb/public.key -o /etc/apt/trusted.gpg.d/trivy.asc && \
        # printf "deb https://aquasecurity.github.io/trivy-repo/deb %s main" "$(lsb_release -sc)" | tee -a /etc/apt/sources.list.d/trivy.list && \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive \
        apt-get -y install -y -qq --no-install-recommends \
            nodejs \
            # trivy \
            yarn \
        && \
        # Install latest Postgres from postgres.org repo
        # curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /etc/apt/trusted.gpg.d/postgresql-ACCC4CF8.asc && \
        # echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list && \
        # echo "Package: *\nPin: release o=apt.postgresql.org\nPin-Priority: 500\n" | tee /etc/apt/preferences.d/pgdg.pref && \
        # apt-get update -qq && \
        # apt-get -y install -y -qq --no-install-recommends libpq-dev postgresql-client &&
        # Install Microsoft ODBC Driver for SQL Server
        # curl -sL https://packages.microsoft.com/keys/microsoft.asc -o /etc/apt/trusted.gpg.d/microsoft.asc && \
        # curl -s https://packages.microsoft.com/config/debian/11/prod.list -o /etc/apt/sources.list.d/mssql-release.list && \
        # export ACCEPT_EULA=Y && \
        # apt-get -qq update -qq && \
        # apt-get -y install -y -qq --no-install-recommends msodbcsql17 && \
        # Install specific version of mysql from MySQL repo
        # mysql-5.7 is not available for Debian Bullseye (11), only Buster (10)
        # The key id comes from this page: https://dev.mysql.com/doc/refman/5.7/en/checking-gpg-signature.html
        # # apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3A79BD29
        # #   gpg: key 3A79BD29: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>" imported
        # export APT_KEY='859BE8D7C586F538430B19C2467B942D3A79BD29' && \
        # export GPGHOME="$(mktemp -d)" && \
        # gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$APT_KEY" && \
        # mkdir -p /etc/apt/keyrings && \
        # gpg --batch --export "$APT_KEY" > /etc/apt/keyrings/mysql.gpg && \
        # gpgconf --kill all && \
        # rm -rf "$GPGHOME" && \
        # rm -rf "${HOME}/.gnupg" && \
        # echo "deb [ signed-by=/etc/apt/keyrings/mysql.gpg ] http://repo.mysql.com/apt/debian/ $(lsb_release -sc) mysql-5.7" | tee /etc/apt/sources.list.d/mysql.list && \
        # echo "Package: *\nPin: release o=repo.mysql.com\nPin-Priority: 500\n" | tee /etc/apt/preferences.d/mysql.pref && \
        # apt-get update -qq && \
        # DEBIAN_FRONTEND=noninteractive \
        # apt-get -y install -y -qq --no-install-recommends libmysqlclient-dev mysql-client && \
        # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
        # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
        # Remove packages installed temporarily. Removes everything related to
        # packages, including the configuration files, and packages
        # automatically installed because a package required them but, with the
        # other packages removed, are no longer needed.
        # apt-get purge -y --auto-remove curl && \
        # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
        # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
        # Delete local repository of retrieved package files in /var/cache/apt/archives
        # This is handled automatically by /etc/apt/apt.conf.d/docker-clean
        # Use this if not running --mount=type=cache.
        # apt-get clean && \
        # Delete info on installed packages. This saves some space, but it can
        # be useful to have them as a record of what was installed, e.g. for auditing.
        # rm -rf /var/lib/dpkg && \
        # Delete debconf data files to save some space
        # rm -rf /var/cache/debconf && \
        # Delete index of available files from apt-get update
        # Use this if not running --mount=type=cache.
        # rm -rf /var/lib/apt/lists/*
        # Clear logs of installed packages
        truncate -s 0 /var/log/apt/* && \
        truncate -s 0 /var/log/dpkg.log

# Get Elixir deps
FROM build-os-deps AS build-deps-get
    ARG APP_DIR
    ENV HOME=$APP_DIR

    WORKDIR $APP_DIR

    # Copy only the minimum files needed for deps, improving caching
    COPY --link config ./config
    COPY --link mix.exs .
    COPY --link mix.lock .

    # COPY --link .env.default ./

    RUN mix 'do' local.rebar --force, local.hex --force

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

    # COPY --link .env.test ./

    # Compile deps separately from app, improving Docker caching
    RUN mix deps.compile

    RUN mix esbuild.install --if-missing

    RUN mix dialyzer --plt

    # Use glob pattern to deal with files which may not exist
    # Must have at least one existing file
    COPY --link .formatter.exs coveralls.jso[n] .credo.ex[s] dialyzer-ignor[e] trivy.yam[l] ./

    # Non-umbrella
    COPY --link lib ./lib
    COPY --link priv ./priv
    COPY --link test ./test
    # COPY --link bin ./bin

    # Umbrella
    # COPY --link apps ./apps
    # COPY --link priv ./priv

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
    ARG MIX_ENV=prod

    WORKDIR $APP_DIR

    # COPY --link .env.prod .

    # Compile deps separately from application for better caching.
    # Doing "mix 'do' compile, assets.deploy" in a single stage is worse
    # because a single line of code changed causes a complete recompile.

    # RUN set -a && . ./.env.prod && set +a && \
    #     env && \
    #     mix deps.compile

    RUN mix deps.compile

    RUN mix esbuild.install --if-missing

    # Install JavaScript deps using yarn
    COPY --link assets/package.jso[n] assets/package.json
    COPY --link assets/package-lock.jso[n] assets/package-lock.json
    COPY --link assets/yarn.loc[k] assets/yarn.lock

    RUN set -exu && \
        mkdir -p ./assets && \
        yarn --cwd ./assets install --prod
        # cd assets && yarn install --prod

    # Install JavaScript deps using npm
    # WORKDIR "${APP_DIR}/assets"
    # COPY --link assets/package.jso[n] ./
    # COPY --link assets/package-lock.jso[n] ./
    # RUN npm install

    # Compile assets the old way
    # WORKDIR "${APP_DIR}/assets"
    #
    # COPY --link assets/package.json ./
    # COPY --link assets/package-lock.json ./
    #
    # RUN --mount=type=cache,target=~/.npm,sharing=locked \
    #     npm --prefer-offline --no-audit --progress=false --loglevel=error ci
    #
    # COPY --link assets ./
    #
    # RUN --mount=type=cache,target=~/.npm,sharing=locked \
    #     npm run deploy
    #
    # Generate assets the really old way
    # RUN --mount=type=cache,target=~/.npm,sharing=locked \
    #     npm install && \
    #     node node_modules/webpack/bin/webpack.js --mode production

    WORKDIR $APP_DIR

    # Compile assets with esbuild
    COPY --link assets ./assets
    COPY --link priv ./priv

    # Non-umbrella
    COPY --link lib ./lib

    # Umbrella
    # COPY --link apps ./apps

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

# Create staging image for files which are copied into final prod image
FROM ${INSTALL_BASE_IMAGE_NAME}:${INSTALL_BASE_IMAGE_TAG} AS prod-install
    ARG LANG
    ARG SNAPSHOT_VER
    ARG RUNTIME_PACKAGES

    # Configure apt caching for use with BuildKit.
    # The default Debian Docker image has special config to clear caches.
    # If we are using --mount=type=cache, then we want it to preserve cached files.
    RUN set -exu && \
        rm -f /etc/apt/apt.conf.d/docker-clean && \
        echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
        echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/99use-gzip-compression

    RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
        --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
        if test -n "$SNAPSHOT_VER" ; then \
            set -exu && \
            apt-get update -qq && \
            DEBIAN_FRONTEND=noninteractive \
            apt-get -y install -y -qq --no-install-recommends \
                ca-certificates \
            && \
            echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} bullseye main" > /etc/apt/sources.list && \
            echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/${SNAPSHOT_VER} bullseye-security main" >> /etc/apt/sources.list && \
            echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} bullseye-updates main" >> /etc/apt/sources.list; \
        fi

    RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
        --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
        set -exu && \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive \
        apt-get -y install -y -qq --no-install-recommends \
            # apt-transport-https \
            ca-certificates \
            curl \
            gnupg-agent \
            # software-properties-common \
            gnupg \
            unzip \
            lsb-release \
            # Needed by Erlang VM
            libtinfo6 \
            # Additional libs
            libstdc++6 \
            libgcc-s1 \
            locales \
            # openssl \
            # $RUNTIME_PACKAGES \
        && \
        # curl -sL https://aquasecurity.github.io/trivy-repo/deb/public.key -o /etc/apt/trusted.gpg.d/trivy.asc && \
        # printf "deb https://aquasecurity.github.io/trivy-repo/deb %s main" "$(lsb_release -sc)" | tee -a /etc/apt/sources.list.d/trivy.list && \
        # apt-get update -qq && \
        # apt-get -y install -y -qq --no-install-recommends trivy && \
        # curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin && \
        # Generate locales specified in /etc/locale.gen
        # If LANG=C.UTF-8 is not enough, build full featured locale
        # sed -i "/${LANG}/s/^# //g" /etc/locale.gen && \
        locale-gen && \
        # localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias /usr/lib/locale/${LANG} && \
        # Remove packages installed temporarily. Removes everything related to
        # packages, including the configuration files, and packages
        # automatically installed because a package required them but, with the
        # other packages removed, are no longer needed.
        # apt-get purge -y --auto-remove curl && \
        # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
        # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
        # Delete local repository of retrieved package files in /var/cache/apt/archives
        # This is handled automatically by /etc/apt/apt.conf.d/docker-clean
        # Use this if not running --mount=type=cache.
        # apt-get clean && \
        # Delete info on installed packages. This saves some space, but it can
        # be useful to have them as a record of what was installed, e.g. for auditing.
        # rm -rf /var/lib/dpkg && \
        # Delete debconf data files to save some space
        # rm -rf /var/cache/debconf && \
        # Delete index of available files from apt-get update
        # Use this if not running --mount=type=cache.
        # rm -rf /var/lib/apt/lists/*
        # Clear logs of installed packages
        truncate -s 0 /var/log/apt/* && \
        truncate -s 0 /var/log/dpkg.log

# Create base image for prod with everything but the code release
FROM ${PROD_BASE_IMAGE_NAME}:${PROD_BASE_IMAGE_TAG} AS prod-base
    ARG SNAPSHOT_VER
    ARG RUNTIME_PACKAGES

    ARG LANG

    ARG APP_DIR
    ARG APP_GROUP
    ARG APP_GROUP_ID
    ARG APP_USER
    ARG APP_USER_ID

    # Create OS user and group to run app under
    RUN if ! grep -q "$APP_USER" /etc/passwd; \
        then groupadd -g "$APP_GROUP_ID" "$APP_GROUP" && \
        useradd -l -u "$APP_USER_ID" -g "$APP_GROUP" -s /usr/sbin/nologin "$APP_USER" && \
        rm /var/log/lastlog && rm /var/log/faillog; fi

    # Configure apt caching for use with BuildKit.
    # The default Debian Docker image has special config to clear caches.
    # If we are using --mount=type=cache, then we want it to preserve cached files.
    RUN set -exu && \
        rm -f /etc/apt/apt.conf.d/docker-clean && \
        echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
        echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/99use-gzip-compression

    RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
        --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
        if test -n "$SNAPSHOT_VER" ; then \
            set -exu && \
            apt-get update -qq && \
            DEBIAN_FRONTEND=noninteractive \
            apt-get -y install -y -qq --no-install-recommends \
                ca-certificates \
            && \
            echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} bullseye main" > /etc/apt/sources.list && \
            echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/${SNAPSHOT_VER} bullseye-security main" >> /etc/apt/sources.list && \
            echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${SNAPSHOT_VER} bullseye-updates main" >> /etc/apt/sources.list; \
        fi

    # Copy just the locale file used
    COPY --link --from=prod-install /usr/lib/locale/${LANG} /usr/lib/locale/${LANG}

    RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
        --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
        set -exu && \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive \
        apt-get -y install -y -qq --no-install-recommends \
            # Enable installation of packages over https
            # apt-transport-https \
            # Enable the app to make outbound SSL calls.
            ca-certificates \
            # Run health checks and get ECS metadata
            # curl \
            wget \
            jq \
            # tini is a minimal init which will reap zombie processes
            # https://github.com/krallin/tini
            # tini \
            # bind-utils \
            # Minimal libs needed by Erlang VM
            libtinfo6 \
            # Additional libs
            libstdc++6 \
            libgcc-s1 \
            # Allow app to listen on HTTPS. May not be needed if handled
            # outside the application, e.g. in load balancer.
            # openssl \
            # $RUNTIME_PACKAGES \
        && \
        # Remove packages installed temporarily. Removes everything related to
        # packages, including the configuration files, and packages
        # automatically installed because a package required them but, with the
        # other packages removed, are no longer needed.
        # apt-get purge -y --auto-remove curl && \
        # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
        # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
        # Delete local repository of retrieved package files in /var/cache/apt/archives
        # This is handled automatically by /etc/apt/apt.conf.d/docker-clean
        # Use this if not running --mount=type=cache.
        # apt-get clean && \
        # Delete info on installed packages. This saves some space, but it can
        # be useful to have them as a record of what was installed, e.g. for auditing.
        # rm -rf /var/lib/dpkg && \
        # Delete debconf data files to save some space
        # rm -rf /var/cache/debconf && \
        # Delete index of available files from apt-get update
        # Use this if not running --mount=type=cache.
        # rm -rf /var/lib/apt/lists/*
        # Clear logs of installed packages
        truncate -s 0 /var/log/apt/* && \
        truncate -s 0 /var/log/dpkg.log

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
    RUN set -exu && \
        # Create app dirs
        mkdir -p "/run/${APP_NAME}" && \
        # Make dirs writable by app
        chown -R "${APP_USER}:${APP_GROUP}" \
            # Needed for RELEASE_TMP
            "/run/${APP_NAME}"

    # USER $APP_USER

    # Setting WORKDIR after USER makes directory be owned by the user.
    # Setting it before makes it owned by root, which is more secure.
    WORKDIR $APP_DIR

    # When using a startup script, copy to /app/bin
    # COPY --link bin ./bin

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
    ARG DEV_PACKAGES

    ARG LANG

    ARG APP_DIR
    ARG APP_GROUP
    ARG APP_NAME
    ARG APP_USER

    ARG DEV_PACKAGES

    # Set environment vars used by the app
    ENV LANG=$LANG \
        HOME=$APP_DIR

    RUN set -exu && \
        # Create app dirs
        mkdir -p "/run/${APP_NAME}" && \
        # Make dirs writable by app
        chown -R "${APP_USER}:${APP_GROUP}" \
            # Needed for RELEASE_TMP
            "/run/${APP_NAME}"

    RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
        --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
        set -exu && \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive \
        apt-get -y install -y -qq --no-install-recommends \
            inotify-tools \
            ssh \
            sudo \
            # $DEV_PACKAGES \
        && \
        # localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias /usr/lib/locale/${LANG} && \
        # https://www.networkworld.com/article/3453032/cleaning-up-with-apt-get.html
        # https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html
        # Remove packages installed temporarily. Removes everything related to
        # packages, including the configuration files, and packages
        # automatically installed because a package required them but, with the
        # other packages removed, are no longer needed.
        # apt-get purge -y --auto-remove curl && \
        # Delete local repository of retrieved package files in /var/cache/apt/archives
        # This is handled automatically by /etc/apt/apt.conf.d/docker-clean
        # Use this if not running --mount=type=cache.
        # apt-get clean && \
        # Delete info on installed packages. This saves some space, but it can
        # be useful to have them as a record of what was installed, e.g. for auditing.
        # rm -rf /var/lib/dpkg && \
        # Delete debconf data files to save some space
        # rm -rf /var/cache/debconf && \
        # Delete index of available files from apt-get update
        # Use this if not running --mount=type=cache.
        # rm -rf /var/lib/apt/lists/*
        # Clear logs of installed packages
        truncate -s 0 /var/log/apt/* && \
        truncate -s 0 /var/log/dpkg.log

    RUN chsh --shell /bin/bash "$APP_USER"

    USER $APP_USER

    WORKDIR $APP_DIR

    RUN mix 'do' local.rebar --force, local.hex --force

    # RUN mix esbuild.install --if-missing

# Copy build artifacts to host
FROM scratch AS artifacts
    ARG MIX_ENV
    ARG RELEASE

    # COPY --from=prod-release "/app/_build/${MIX_ENV}/rel/${RELEASE}" /release
    COPY --from=prod-release /app/priv/static /static

# Default target
FROM prod
