FROM dawnoflight/dolsharp:alpine

ARG BUILD_DATE=now
ARG VCS_REF=local

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.schema-version="1.0.0-rc1" \
      maintainer="Leodagan <leodagan@freyad.net>"

RUN set -ex; \
    # Set Constants
    DOL_DB_DOWNLOAD="https://github.com/Eve-of-Darkness/db-public/archive/master.zip"; \
    # Install Build Dependencies
    echo "@testing http://dl-4.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories; \
    mkdir /var/cache/apk; \
    apk update; \
    apk add --no-cache --update --virtual .build_dependencies sqlite curl unzip jq; \
    # Use DOL to create table
    rm -f /dawn-of-light/dol.sqlite3.db; \
    echo "exit" | mono-sgen --server DOLServer.exe; \
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
    rm -f /dawn-of-light/config/* /dawn-of-light/logs/*; \
    apk del .build_dependencies; \
    rm -rf /var/cache/* /tmp/* /var/log/* ~/.cache;

COPY /scripts /dawn-of-light/scripts/Utility
COPY sandbox.sh /

CMD [ "/sandbox.sh" ]
