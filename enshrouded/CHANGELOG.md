# Changelog

## 1.1.1

- Stürzt der Server mit Mods direkt nach dem Start ab (z. B. weil die Mod nach einem
  Spiel-Update nicht mehr zum Server-Build passt), läuft er automatisch ohne Mods weiter,
  statt in einer Absturzschleife zu enden. Das Mod-Log wird dabei im App-Log ausgegeben.

## 1.1.0

- Mod-Unterstützung: Dateien und `.zip`-Archive aus `mods/` im App-Konfigurationsordner
  werden bei jedem Start neben `enshrouded_server.exe` gelegt
- Mod-DLLs bekommen automatisch einen Wine-Override (`native,builtin`), z. B. `dbghelp.dll`
- Neue Option `enable_mods` zum schnellen Abschalten

## 1.0.0

- Erste Version: Enshrouded Dedicated Server unter GE-Proton 11-9
- Admin-, Freunde- und Gast-Gruppe über die App-Konfiguration
- Automatische Updates, die warten, bis niemand online ist
- RAM-Wächter mit sauberem Neustart
- Spielstände und `enshrouded_server.json` im App-Konfigurationsordner
