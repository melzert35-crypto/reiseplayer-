# ReisePlayer – Update 0.2

Android-Startpaket mit:
- lokaler Musik- und Videobibliothek
- Pause und Stoppen (Stop setzt den aktuellen Titel an den Anfang zurück)
- neuer Rubrik **Entdecken**
- Suchfeld für Titel, Interpret und Musikstil
- Suche über Free Music Archive, Jamendo, Bandcamp und SoundCloud
- Suche öffnet die Webtreffer im Browser; Downloads nur, wenn der Anbieter sie freigibt

## GitHub-Ordnerstruktur

```text
reiseplayer/
├── .github/
│   └── workflows/
│       └── android.yml
├── app/
│   ├── analysis_options.yaml
│   ├── pubspec.yaml
│   └── lib/
│       └── main.dart
└── README.md
```

Die Inhalte aus diesem ZIP müssen direkt in das Hauptverzeichnis des Repositorys übertragen werden.
Nicht den äußeren ZIP-Ordner als zusätzlichen Unterordner hochladen.

## APK bauen

1. Dateien mit exakt dieser Ordnerstruktur ins Repository hochladen.
2. GitHub → Actions öffnen.
3. **ReisePlayer Android APK** auswählen.
4. Workflow starten bzw. den durch den Upload ausgelösten Lauf öffnen.
5. Nach erfolgreichem Build das Artefakt `reiseplayer-android-apk` herunterladen.

## Hinweise

- Die Musiksuche verwendet eine Websuche mit auf die vier Anbieter begrenzten Suchbegriffen. Sie ist keine direkte Katalog-API und zeigt daher die vom Anbieter bzw. der Suchmaschine indexierten Treffer.
- Ein Treffer ist nicht automatisch kostenlos oder herunterladbar. Lizenz und Download-Freigabe bitte auf der Anbieterseite prüfen.
- YouTube wird separat geöffnet; geschützte Streams werden nicht heruntergeladen.
- Der Build wurde vor dem Bereitstellen dieses Pakets nicht auf einem Android-Gerät ausgeführt. Bitte den GitHub-Actions-Build prüfen.
