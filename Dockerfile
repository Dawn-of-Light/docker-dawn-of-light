FROM mono:slim

ARG BUILD_DATE=now
ARG VCS_REF=local
ARG BUILD_VERSION=dev

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.version=$BUILD_VERSION \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Dawn-of-Light/docker-dawn-of-light.git" \
      org.label-schema.name="dawn-of-light" \
      org.label-schema.description="Dawn of Light (DOL) - Dark Age of Camelot (DAOC) Server Emulator" \
      org.label-schema.usage="https://github.com/Dawn-of-Light/docker-dawn-of-light/blob/master/README.md" \
      org.label-schema.schema-version="1.0.0-rc1" \
      maintainer="Leodagan <leodagan@freyad.net>"

RUN set -ex; \
    # Set Constants
    DOL_ARCHIVE_NAME="DOLServer_linux_net45_Release.zip"; \
    DOL_GITHUB_API_URL="https://api.github.com/repos/Dawn-of-Light/DOLSharp/releases/latest"; \
    # Install Build Dependencies
    apt-get update; \
    BUILD_DEPS=" \
        curl \
        unzip \
        jq \
        "; \
    apt-get install --no-install-recommends -y $BUILD_DEPS; \
    # Get DOL Release
    DOL_RELEASE_CONTENT="$(curl -s "$DOL_GITHUB_API_URL")"; \
    DOL_RELEASE_NAME="$(echo "$DOL_RELEASE_CONTENT" | jq -r ".name")"; \
    echo "Building with DOL Release $DOL_RELEASE_NAME"; \
    DOL_LATEST_RELEASE_URL=$(echo "$DOL_RELEASE_CONTENT" |  jq -r ".assets[] | select(.name == \"$DOL_ARCHIVE_NAME\") | .browser_download_url"); \
    curl -L -o /DOLServer_linux_net45_Release.zip "$DOL_LATEST_RELEASE_URL"; \
    unzip "/$DOL_ARCHIVE_NAME" -d /dawn-of-light; \
    # Cleanup Download
    rm -f "/$DOL_ARCHIVE_NAME"; \
    # Cleanup Build Dependencies
    apt-get purge -y $BUILD_DEPS; \
    apt-get autoremove -y; \
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/* /tmp/* /var/log/* ~/.cache; \
    # Prerequisites
    mkdir -p /dawn-of-light/config /dawn-of-light/database

COPY /scripts /

WORKDIR /dawn-of-light

CMD [ "/entrypoint.sh" ]
