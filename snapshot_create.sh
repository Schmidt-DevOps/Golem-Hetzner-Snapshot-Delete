#!/bin/bash

# Dieses Script ermöglicht es, Hetzner-Cloud-Snapshots automatisiert erstellen zu lassen.

usage() {
    echo "Nutzung: $0 -c <context> -s <server> [-y] [-h]"
    echo "Optionen:"
    echo "  -c <context> Kontext für die Operation"
    echo "  -s <server>  Servername"
    echo "  -y           Interaktive Fragen immer mit 'ja' beantworten"
    echo "  -h           Hilfe anzeigen"
    exit 1
}

error_out() {
    MSG="${1}"
    echo $MSG
    exit 1
}

check_requirements() {
    if ! which hcloud >/dev/null 2>/dev/null; then
        error_out "Bitte installiere 'hcloud' https://github.com/hetznercloud/cli"
    fi
}

shutdown_server() {
    SERVER="${1}"
    if ! hcloud server shutdown --poll-interval 5000ms "${SERVER}"; then
        error_out "'${SERVER}' konnte nicht heruntergefahren werden."
    fi

    RETRIES=20
    while :; do
        echo -n "."

        RETRIES=$((RETRIES - 1))

        if [ $RETRIES -lt 0 ]; then
            error_out "'${SERVER}' konnte nicht heruntergefahren werden."
        fi

        SERVERS_FOUND=$(hcloud server list -o columns=name,status -o noheader | grep -c "${SERVER}.*running")

        if [[ $SERVERS_FOUND -lt 1 ]]; then
            break
        fi

        sleep 3
    done
}

create_snapshot() {
    SERVER="${1}"
    UUID=$(uuidgen)
    if ! hcloud server create-image --type snapshot "${SERVER}" --description "${SERVER}-${UUID}" --label "name=${SERVER}"; then
        error_out "Konnte Snapshot für '${SERVER}' nicht erstellen."
    fi
}

check_requirements

TEMP=$(getopt -o c:s:yh --long context:,yes,help -n "$0" -- "$@")
if [ $? != 0 ]; then
    usage
fi

eval set -- "$TEMP"

context=""
server=""

while true; do
    case "$1" in
    -c | --context)
        context="$2"
        shift 2
        ;;
    -s | --server)
        server="$2"
        shift 2
        ;;
    -y | --yes)
        yes=true
        shift
        ;;
    -h | --help)
        usage
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Interner Fehler!"
        exit 1
        ;;
    esac
done

if [[ -z $context ]] || [[ -z $server ]]; then
    usage
fi

# Not using `hcloud context use "${context}"` as it can disturb parallel hcloud "sessions"
export HCLOUD_CONTEXT="${context}"

pending_power_on=false
REPLY="j"
if [[ "${yes}" != true ]]; then
    echo "Hetzner empfiehlt, den Server vor Erstellen eines Snapshots runterzufahren."
    read -p "'${server}' runterfahren und wieder hochfahren vor Erstellen des Snapshots? (jN) "
fi

if [[ $REPLY =~ ^[yj]$ ]]; then
    shutdown_server "${server}"
    pending_power_on=true
fi

create_snapshot "${server}"

if [[ "${pending_power_on}" = true ]]; then
    if ! hcloud server poweron "${server}"; then
        error_out "Konnte '${server}' nicht wieder hochfahren."
    fi
fi

echo "Fertig."
