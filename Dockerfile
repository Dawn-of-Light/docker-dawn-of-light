FROM ubuntu:focal AS dotnet_runtime
ENV DOTNET_ROOT=/dotnet
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV PATH=$PATH:/dotnet
RUN set -ex; \
    DEPS="ca-certificates wget"; \
    apt-get update && apt-get install -y --no-install-recommends $DEPS; \
    wget https://download.visualstudio.microsoft.com/download/pr/c1d77e74-541f-40a6-b84d-edc6626530f1/d65b9d134f80a8cbc0d4ee6437f67bf5/dotnet-runtime-5.0.11-linux-arm64.tar.gz -O dotnet.tar.gz; \
    mkdir /dotnet && tar -xf dotnet.tar.gz -C /dotnet && rm dotnet.tar.gz; \
    apt-get purge -y $DEPS; \
    apt-get autoremove -y; \
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/* /tmp/* /var/log/* ~/.cache;


FROM dotnet_runtime:latest AS dol_sandbox
ARG BUILD_VERSION=latest
RUN set -ex; \
    # Set Constants
    DOL_ARCHIVE_NAME="DOLServer_Net5_Alpha_Debug.zip"; \
    DOL_GITHUB_API_URL="https://api.github.com/repos/Dawn-of-Light/DOLSharp/releases/latest"; \
    [ "$BUILD_VERSION" != "latest" ] && DOL_GITHUB_API_URL="https://api.github.com/repos/Dawn-of-Light/DOLSharp/releases/tags/$BUILD_VERSION"; \
    # Install Build Dependencies
    BUILD_DEPS="ca-certificates curl unzip jq tmux"; \
    apt-get update && apt-get install --no-install-recommends -y $BUILD_DEPS; \
    # Get DOL Release
    DOL_LATEST_RELEASE_URL=$(curl -s "$DOL_GITHUB_API_URL" |  jq -r ".assets[] | select(.name == \"$DOL_ARCHIVE_NAME\") | .browser_download_url"); \
    curl -L -o "/$DOL_ARCHIVE_NAME" "$DOL_LATEST_RELEASE_URL"; \
    unzip "/$DOL_ARCHIVE_NAME" -d /dawn-of-light; \
    rm -f /dawn-of-light/dol.sqlite3.db; \
    chmod +x /dawn-of-light/DOLServer.dll; \
    # Cleanup Download
    rm -f "/$DOL_ARCHIVE_NAME"; \
    # Cleanup Build Dependencies
    apt-get purge -y $BUILD_DEPS; \
    apt-get autoremove -y; \
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/* /tmp/* /var/log/* ~/.cache; \
    # Prerequisites
    mkdir -p /dawn-of-light/config /dawn-of-light/database
WORKDIR /dawn-of-light

FROM dol_sandbox AS dbpublic
RUN set -ex; \
    # Set Constants
    BUILD_DEPS="ca-certificates sqlite3 curl unzip jq"; \
    DOL_DB_DOWNLOAD="https://github.com/Eve-of-Darkness/db-public/archive/master.zip"; \
    # Install Build Dependencies
    apt-get update; \
    apt-get install -y --no-install-recommends $BUILD_DEPS; \
    # Use DOL to create table
    echo "exit" | /dotnet/dotnet DOLServer.dll; \
    # Get DOL Database
    curl -L -o /db.zip "$DOL_DB_DOWNLOAD"; \
    unzip /db.zip -d /db; \
    # Insert database content
    echo 'DELETE FROM AutoXMLUpdate; \
          DELETE FROM ItemTemplate; \
          DELETE FROM NpcTemplate; \
          DELETE FROM Mob; \
          DELETE FROM Regions; \
          DELETE FROM StartupLocation; \
          DELETE FROM Zones;' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    for json in "/db/db-public-master/src/data/"*.json; do \
        echo "Inserting $json"; \
        if [ "$(basename "$json")" = "LineXSpell.json" ]; then \
            jq 'del(.[].PackageID)' "$json" > "$json".tmp; \
            mv -f "$json".tmp "$json"; \
        fi; \
        jq --raw-output '(.[0] | keys) as $fields | \
        (input_filename | gsub(".*/"; "") | gsub("(\\.[0-9]+)?\\.json"; ""; "i")) as $tablename | \
        ($fields | map("`" + . +"`") | join(", ")) as $cols | \
        (map( [.[$fields[]]] | map(if . == null then "null" else "'"'"'" + (. | tostring | gsub("'"'"'"; "'"''"'"; "g")) + "'"'"'" end) | "(" + (. | join(", "))+ ")" ) | join(",\n    ")) as $tuples | \
        "PRAGMA synchronous=OFF; PRAGMA journal_mode=MEMORY; BEGIN TRANSACTION;\nINSERT INTO `" + $tablename + "`\n" + \
        "    (" + $cols + ")\n" + \
        "VALUES\n    " + $tuples + ";\n" + \
        "COMMIT;"' \
        "$json" | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    done; \
    # Cleanup database
    rm -rf /db /db.zip; \
    # Feed Database
    echo 'UPDATE `ServerProperty` SET `Value` = "Welcome to the Administrator Sandbox Dark Age of Camelot Shard - This Server is meant for testing and experimenting Admin Commands" WHERE `Key` = "starting_msg"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    echo 'UPDATE `ServerProperty` SET `Value` = "The Server Database is reset twice a day, feel free to edit or test anything you want !" WHERE `Key` = "motd"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    echo 'UPDATE `ServerProperty` SET `Value` = "/code" WHERE `Key` = "disabled_commands"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    echo 'UPDATE `ServerProperty` SET `Value` = "False" WHERE `Key` = "load_examples"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    echo 'UPDATE `ServerProperty` SET `Value` = "12" WHERE `Key` = "hours_uptime_between_shutdown"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    # Cleanup
    apt-get purge -y $BUILD_DEPS; \
    apt-get autoremove -y; \
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/* /tmp/* /var/log/* ~/.cache; \
    rm -f /dawn-of-light/config/* /dawn-of-light/logs/*; 

FROM dol_sandbox
ARG BUILD_DATE=now
ARG VCS_REF=local
ARG BUILD_DATE=now
ARG VCS_REF=local
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.version=$BUILD_VERSION \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Dawn-of-Light/docker-dawn-of-light.git" \
      org.label-schema.name="dawn-of-light" \
      org.label-schema.description="Dawn of Light (DOL) - Dark Age of Camelot (DAOC) Server Emulator" \
      org.label-schema.usage="https://github.com/Dawn-of-Light/docker-dawn-of-light/blob/master/README.md" \
      org.label-schema.schema-version="1.0.0-rc1" \
      maintainer="Leodagan <leodagan@freyad.net>"
COPY --from=dbpublic /dawn-of-light/dol.sqlite3.db /dawn-of-light/database
COPY /scripts /dawn-of-light/scripts/Utility
RUN set -ex; \
    # Set Constants
    BUILD_DEPS="tmux libssl1.1"; \
    # Install Build Dependencies
    apt-get update; \
    apt-get install -y --no-install-recommends $BUILD_DEPS; \
    # Cleanup
    apt-get autoremove -y; \
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/* /tmp/* /var/log/* ~/.cache; \
    rm -f /dawn-of-light/config/* /dawn-of-light/logs/*; 
COPY sandbox.sh /
COPY entrypoint.sh /
CMD [ "/entrypoint.sh" ]
