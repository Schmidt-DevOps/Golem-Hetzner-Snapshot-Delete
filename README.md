# Golem-Hetzner-Snapshot-Delete

Einfaches hcloud-Demoskript zum Erstellen und Löschen von Hetzner-Cloud-Server-Snapshots.

## Ein API-Token generieren

1. Anmelden bei Hetzner Cloud admin
2. Projekt auswählen
3. Gehen Sie zu „Sicherheit > API-Tokens“
4. Erstellen Sie ein r/w API-Token „mein-projekt-kontext".
5. Führen Sie „hcloud context create mein-projekt-kontext“ aus und geben Sie das neue API-Token ein.

## Nutzung snapshot_create.sh

```bash
Nutzung: ./snapshot_create.sh -c <context> [-h]
Optionen:
  -c <context> Kontext für die Operation
  -s <server>  Servername
  -y           Interaktive Fragen immer mit 'ja' beantworten
  -h           Hilfe anzeigen
```

## Nutzung snapshot_delete.sh

```bash
Nutzung: ./snapshot_delete.sh -c <context> -m <alter_in_tagen> [-f] [-y] [-h]
Optionen:
  -c <context>        Kontext für die Operation
  -s <server>         Servername
  -m <alter_in_tagen> Maximales Snapshot-Alter in Tagen
  -f                  Änderungen forcieren, nicht simulieren
  -y                  Interaktive Fragen immer mit 'ja' beantworten
  -h                  Hilfe anzeigen
```

## Links

1. <https://jqlang.github.io/jq/download/>
2. <https://github.com/hetznercloud/cli>
3. <https://docs.hetzner.com/de/general/others/new-billing-model>
4. <https://docs.hetzner.com/de/cloud/servers/backups-snapshots/overview>
5. <https://github.com/fbrettnich/hcloud-snapshot-as-backup>
6. <https://docs.hetzner.com/de/cloud/servers/backups-snapshots/faq>
