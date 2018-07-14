FROM alpine:edge

ARG BUILD_DATE=now
ARG VCS_REF=local
ARG BUILD_VERSION=latest

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
    # Setting DOL Release Vars
    DOL_ARCHIVE_NAME="DOLServer_linux_net45_Release.zip"; \
    DOL_GITHUB_API_URL="https://api.github.com/repos/Dawn-of-Light/DOLSharp/releases/latest"; \
    [ "$BUILD_VERSION" != "latest" ] && DOL_GITHUB_API_URL="https://api.github.com/repos/Dawn-of-Light/DOLSharp/releases/tags/$BUILD_VERSION"; \
    # Installing needed packages
    echo "@testing http://dl-4.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories; \
    apk update; \
    apk add --no-cache --update \
        mono@testing tmux; \
    # Installing build dependencies
    apk add --no-cache --update --virtual .build_dependencies \
        curl jq unzip ca-certificates; \
    update-ca-certificates; \
    # Downloading DOL Release
    DOL_LATEST_RELEASE_URL=$(curl -s "$DOL_GITHUB_API_URL" |  jq -r ".assets[] | select(.name == \"$DOL_ARCHIVE_NAME\") | .browser_download_url"); \
    curl -L -o /DOLServer_linux_net45_Release.zip "$DOL_LATEST_RELEASE_URL"; \
    unzip "/$DOL_ARCHIVE_NAME" -d /dawn-of-light; \
    # Cleaning up download
    rm -f "/$DOL_ARCHIVE_NAME"; \
    # Cleaning up build dependencies
    apk del .build_dependencies; \
    rm -rf /var/cache/* /tmp/* /var/log/* ~/.cache; \
    # Prerequisites
    mkdir -p /dawn-of-light/config /dawn-of-light/database

COPY /scripts /

WORKDIR /dawn-of-light

CMD [ "/entrypoint.sh" ]
