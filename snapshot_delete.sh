#!/bin/bash

# Dieses Script ermöglicht es, Hetzner-Cloud-Snapshots interaktiv oder automatisiert löschen zu lassen.

usage() {
    echo "Nutzung: $0 -c <context> -s <server> -m <alter_in_tagen> [-f] [-y] [-h]"
    echo "Optionen:"
    echo "  -c <context>        Kontext für die Operation"
    echo "  -s <server>         Servername"
    echo "  -m <alter_in_tagen> Maximales Snapshot-Alter in Tagen"
    echo "  -f                  Änderungen forcieren, nicht simulieren"
    echo "  -y                  Interaktive Fragen immer mit 'ja' beantworten"
    echo "  -h                  Hilfe anzeigen"
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

    if ! which jq >/dev/null 2>/dev/null; then
        error_out "Bitte installiere 'jq' https://jqlang.github.io/jq/download/ "
    fi
}

check_requirements

TEMP=$(getopt -o c:s:m:yfh --long context:,server:,alter_in_tagen:,yes,force,help -n "$0" -- "$@")
if [ $? != 0 ]; then
    usage
fi

eval set -- "$TEMP"

context=""
server=""
alter_in_tagen=""
yes=false
force=false
force_changes="Starten Sie das Script mit '-f' erneut, um die Änderungen tatsächlich zu veranlassen."

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
    -m | --max-age-in-days)
        if [[ "$2" =~ ^[0-9]+$ ]]; then
            alter_in_tagen="$2"
        else
            echo "Fehler: alter_in_tagen muss eine postive ganze Zahl sein."
            usage
        fi
        shift 2
        ;;
    -f | --Force)
        force=true
        shift
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

if [[ -z $context ]] || [[ -z $alter_in_tagen ]] || [[ -z $server ]]; then
    usage
fi

# Not using `hcloud context use "${context}"` as it can disturb parallel hcloud "sessions"
export HCLOUD_CONTEXT="${context}"

# 'map(select(...))'' retains the array structure. '.[] | select(...)' would return each object individually.
SNAPSHOTS=$(hcloud image list -o json -t snapshot | jq 'map(select(.created < (now - '"${alter_in_tagen}"' * 86400 | todate) and .created_from.name == "'"${server}"'"))')
RET=$?
[[ $RET != 0 ]] && error_out "Konnte keine Snapshot-Liste für '${server}' erhalten."

amount=$(echo "${SNAPSHOTS}" | jq 'length')
if [[ $amount -eq 0 ]]; then
    echo "Es wurden keine Snapshots für '${server}' gefunden, die älter als ${alter_in_tagen} Tage sind."
    exit 0
fi

max=$((amount - 1))
snapshot_size_deleted=0

for ((i = 0; i <= max; i++)); do
    id=$(echo "$SNAPSHOTS" | jq -r '.['$i'].id')
    description=$(echo "$SNAPSHOTS" | jq -r '.['$i'].description')
    snapshot_size_gb=$(echo "$SNAPSHOTS" | jq -r '.['$i'].image_size')
    n_of="$((i + 1))/${amount}"

    if [[ "${description}" == "lts" ]] || [[ "${description}" == "hold" ]]; then
        echo "${n_of}: Behalte Snapshot 'lts/hold' (ID '${id}', Server '${server}')."
        continue
    fi

    snapshot_size_gb=${snapshot_size_gb%.*}
    created=$(echo "$SNAPSHOTS" | jq -r '.['$i'].created')

    if [[ "${yes}" != true ]]; then
        read -p "${n_of}: Snapshot ID '${id}' (Server '${server}') vom ${created} (~${snapshot_size_gb} GB) löschen? (jN) "
        if [[ ! $REPLY =~ ^[yj]$ ]]; then
            continue
        fi
    fi

    snapshot_size_deleted=$((snapshot_size_deleted + snapshot_size_gb))
    if [[ "${force}" != true ]]; then
        echo "${n_of}: Hätte Snapshot ID '${id}' (Server '${server}') gelöscht."
    else
        echo -n "${n_of}: Lösche Snapshot ID '${id}' (Server '${server}')… "
        if ! hcloud image delete "${id}"; then
            echo "FEHLER: Konnte Snapshot ID ${id} ('${description}', Server '${server}') nicht löschen."
        fi
    fi
done

if [[ "${force}" != true ]]; then
    echo "~${snapshot_size_deleted} GB Snapshots von Server '${server}' wären gelöscht worden. ${force_changes}"
else
    echo "~${snapshot_size_deleted} GB Snapshots von Server '${server}' wurden gelöscht."
fi
