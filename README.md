# ReisePlayer – Android Startpaket

Dieses Paket ist der erste lauffähige Grundaufbau für eine persönliche Offline-Mediathek.

## Was Version 0.1 kann
- Musikdateien vom Handy auswählen und in die private App-Mediathek kopieren
- Videodateien auswählen und lokal speichern
- importierte Musik in der App abspielen
- importierte Videos in der App abspielen
- Dateien aus der Mediathek löschen
- YouTube separat in der offiziellen App bzw. im Browser öffnen (Online-Wiedergabe)

## Was ausdrücklich noch nicht enthalten ist
- kein Downloader für YouTube oder geschützte Streamingdienste
- keine Umgehung von Downloadbeschränkungen oder Kopierschutz
- keine automatische Suche nach Musik aus dem Internet
- noch keine Hintergrundwiedergabe bei geschlossener App
- noch keine iPhone-Version

YouTube-Inhalte, die nicht offiziell zum Download freigegeben sind, können nicht in die lokale Mediathek kopiert werden. Die App spielt dagegen eigene Dateien und legal heruntergeladene Musik/Videos offline ab.

## Dateien in GitHub
Die ZIP enthält:
- `.github/workflows/android.yml`
- `app/pubspec.yaml`
- `app/lib/main.dart`
- `app/analysis_options.yaml`

Der Workflow erzeugt beim Build ein frisches Flutter-Android-Projekt und kopiert den App-Code hinein. Deshalb müssen keine automatisch erzeugten Android-/Gradle-Dateien von Hand hochgeladen werden.

## GitHub-Voraussetzung
Neues Repository anlegen, zum Beispiel `reiseplayer`, mit Branch `main`.
Dann die vier enthaltenen Dateien mit exakt derselben Ordnerstruktur hochladen und committen.
Danach in GitHub auf **Actions** gehen. Der Workflow **ReisePlayer Android APK** startet automatisch. Die fertige APK liegt nach erfolgreichem Lauf unter **Artifacts** als `reiseplayer-android-apk`.

## Build-Umgebung
Flutter 3.35.1, Java 17. Das Projekt ist auf Android ausgelegt.
