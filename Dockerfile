FROM dawnoflight/dolsharp:alpine

ARG BUILD_DATE=now
ARG VCS_REF=local

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.schema-version="1.0.0-rc1" \
      maintainer="Leodagan <leodagan@freyad.net>"

RUN set -ex; \
    # Set Constants
    DOL_DB_DOWNLOAD="https://github.com/dol-leodagan/DOLAutoXMLPublic/archive/hunabku.zip"; \
    # Install Build Dependencies
    echo "@testing http://dl-4.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories; \
    mkdir /var/cache/apk; \
    apk update; \
    apk add --no-cache --update --virtual .build_dependencies sqlite curl unzip; \
    # Get DOL Database
    curl -L -o /db.zip "$DOL_DB_DOWNLOAD"; \
    unzip /db.zip -d /db; \
    # Update content and move it to DOLServer script directory
    mv /db/*/* /db; \
    cat /db/Mob.xml.* > /db/Mob.xml; \
    mv /db/*.xml /dawn-of-light/scripts/dbupdater/insert/; \
    rm -rf /db; \
    # Use DOL to insert data
    echo "exit" | mono-sgen --server DOLServer.exe; \
    # Feed Database
    echo 'UPDATE `ServerProperty` SET `Value` = "Welcome to the Administrator Sandbox Dark Age of Camelot Shard - This Server is meant for testing and experimenting Admin Commands" WHERE `Key` = "starting_msg"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    echo 'UPDATE `ServerProperty` SET `Value` = "The Server Database is reset twice a day, feel free to edit or test anything you want !" WHERE `Key` = "motd"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    echo 'UPDATE `ServerProperty` SET `Value` = "/code" WHERE `Key` = "disabled_commands"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    echo 'UPDATE `ServerProperty` SET `Value` = "False" WHERE `Key` = "load_examples"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    echo 'UPDATE `ServerProperty` SET `Value` = "12" WHERE `Key` = "hours_uptime_between_shutdown"' | sqlite3 /dawn-of-light/dol.sqlite3.db; \
    # Cleanup
    rm -rf /dawn-of-light/scripts/dbupdater/insert/*; \
    rm -f /dawn-of-light/config/* /dawn-of-light/logs/*; \
    apk del .build_dependencies; \
    rm -rf /var/cache/* /tmp/* /var/log/* ~/.cache;

COPY /scripts /dawn-of-light/scripts/Utility
COPY sandbox.sh /

CMD [ "/sandbox.sh" ]
