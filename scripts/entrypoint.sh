#!/bin/sh

## Detect Memory Constraints
CONTAINER_MEMORY_CONSTRAINTS="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)"

if [ "${DOL_MEMORY_LIMIT:-0}" -gt "$CONTAINER_MEMORY_CONSTRAINTS" ]; then DOL_MEMORY_LIMIT=$CONTAINER_MEMORY_CONSTRAINTS; fi

## Create Config file if doesn't exists
if [ ! -f "config/serverconfig.xml" ]; then

    case ${DOL_DB_TYPE:-SQLITE} in
        "SQLITE")
	    if [ "${DOL_SQLITE_CACHE:-0}" -gt $(( CONTAINER_MEMORY_CONSTRAINTS / 2 / 1024 )) ]; then DOL_SQLITE_CACHE=$(( CONTAINER_MEMORY_CONSTRAINTS / 2 / 1024 )); fi
	    if [ "${DOL_SQLITE_CACHE}x" != "x" ]; then DOL_SQLITE_CACHE_CONFIG="Cache Size=-${DOL_SQLITE_CACHE}"; fi
            DATABASE_CONNECTIONSTRING="Data Source=$(pwd)/database/dol.sqlite3.db;Version=3;${DOL_SQLITE_CACHE_CONFIG}Pooling=False;Journal Mode=Off;Synchronous=Off;Foreign Keys=True;Default Timeout=60"
        ;;
        "MYSQL")
            DATABASE_CONNECTIONSTRING="Server=${DOL_MYSQL_HOST:-localhost};Port=${DOL_MYSQL_PORT:-3306};Database=${DOL_MYSQL_DB:-dolserver};User ID=${DOL_MYSQL_USER:-root};Password=${DOL_MYSQL_PASSWORD};Treat Tiny As Boolean=False"
        ;;
        *)
            echo "Unknown DOL_DB_TYPE : ${DOL_DB_TYPE}"
            exit 1
        ;;
    esac

    cat <<EOT > "config/serverconfig.xml"
<?xml version="1.0" encoding="utf-8"?>
<root>
  <Server>
    <Port>${DOL_TCP_PORT:-10300}</Port>
    <IP>0.0.0.0</IP>
    <RegionIP>0.0.0.0</RegionIP>
    <RegionPort>${DOL_REGION_PORT:-10400}</RegionPort>
    <UdpIP>0.0.0.0</UdpIP>
    <UdpPort>${DOL_UDP_PORT:-10400}</UdpPort>
    <EnableUPnP>False</EnableUPnP>
    <DetectRegionIP>True</DetectRegionIP>
    <ServerName>${DOL_SERVER_NAME:-Dawn Of Light}</ServerName>
    <ServerNameShort>${DOL_SERVER_NAMESHORT:-DOLSERVER}</ServerNameShort>
    <LogConfigFile>./config/logconfig.xml</LogConfigFile>
    <ScriptCompilationTarget>./lib/GameServerScripts.dll</ScriptCompilationTarget>
    <ScriptAssemblies>${DOL_SCRIPTS_ASSEMBLIES:-System.dll,System.Xml.dll}</ScriptAssemblies>
    <EnableCompilation>True</EnableCompilation>
    <AutoAccountCreation>${DOL_AUTO_ACCOUNTCREATION:-True}</AutoAccountCreation>
    <GameType>${DOL_GAME_TYPE:-Normal}</GameType>
    <CheatLoggerName>cheats</CheatLoggerName>
    <GMActionLoggerName>gmactions</GMActionLoggerName>
    <InvalidNamesFile>./config/invalidnames.txt</InvalidNamesFile>
    <DBType>${DOL_DB_TYPE:-SQLITE}</DBType>
    <DBConnectionString>${DOL_DB_CONNECTIONSTRING:-${DATABASE_CONNECTIONSTRING}}</DBConnectionString>
    <DBAutosave>${DOL_DB_AUTOSAVE:-True}</DBAutosave>
    <DBAutosaveInterval>${DOL_DB_AUTOSAVE_INTERVAL:-10}</DBAutosaveInterval>
    <CpuUse>${DOL_CPU_USE:-4}</CpuUse>
  </Server>
</root>
EOT

fi

## Setup Mono Options
export LANG=en_US.CP1252
export LC_COLLATE=C
export MONO_GC_PARAMS="concurrent-sweep"
if [ "${DOL_MEMORY_LIMIT}x" != "x" ]; then MONO_GC_PARAMS="${MONO_GC_PARAMS},max-heap-size=${DOL_MEMORY_LIMIT}"; fi

trap quit_server HUP INT QUIT TERM

quit_server() {
    echo "Stopping DOL Server..."
    tmux send-keys -t dolserver "exit" Enter
    MAX_WAIT=30
    while [ "$MAX_WAIT" -gt 0 ] && [ -n "$(pgrep mono-sgen)" ]; do
        echo "Waiting for DOL Server to stop..."
	sleep 1
	MAX_WAIT=$(( MAX_WAIT - 1 ))
    done
    echo "Stopping DOL Server finished..."
    exit 0
}

## Start Server
echo "Starting DOL Server..."

mkfifo /tmp/DOLServer.pipe
tmux new-session -s dolserver -d 'mono-sgen --server DOLServer.exe' \; pipe-pane 'cat >> /tmp/DOLServer.pipe'
cat /tmp/DOLServer.pipe &
wait

echo "DOL Server Stopped..."
