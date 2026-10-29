# Enshrouded Server für Home Assistant

Ein dedizierter Enshrouded-Server als Home-Assistant-App (früher „Add-on“).
Er läuft als Docker-Container auf deinem Home Assistant und ist für Freunde über
das Internet erreichbar.

## Inhalt

```
enshrouded/
├── config.yaml          App-Definition (Ports, Optionen, Backup-Regeln)
├── Dockerfile           Debian 13 + SteamCMD + GE-Proton
├── DOCS.md              Ausführliche Anleitung (erscheint in HA unter „Dokumentation“)
├── translations/        Beschriftungen der Optionen (de/en)
└── rootfs/opt/enshrouded/
    ├── run.sh           Update, Konfiguration, Start, Überwachung, RAM-Wächter
    ├── a2s_players.py   Fragt die Spielerzahl ab (für Updates ohne Rauswurf)
    └── enshrouded_server.default.json
```

## Schnellstart

1. In Home Assistant: Einstellungen → Apps → App-Store → ⋮ → **Repositories** →
   `https://github.com/beumelee/Enshrouded-HA` hinzufügen.
2. Seite neu laden, **Enshrouded Dedicated Server** öffnen und installieren.
3. Admin- und Freunde-Passwort setzen, starten.
4. Am Router **UDP 15637** auf den Home-Assistant-Rechner weiterleiten.

Neue Versionen erscheinen in Home Assistant als Update, sobald `version` in
`enshrouded/config.yaml` erhöht wird.

Alle Details, auch zur FRITZ!Box und zu DS-Lite, stehen in
[`enshrouded/DOCS.md`](enshrouded/DOCS.md).

## Hinweise

- Nur für Intel/AMD-Rechner (x86-64), nicht für Raspberry Pi.
- Der Proton-Aufbau orientiert sich an
  [jsknnr/enshrouded-server](https://github.com/jsknnr/enshrouded-server) (MIT-Lizenz).
- Kein offizielles Produkt von Keen Games oder Home Assistant.
