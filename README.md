# Overlight

Versione app (Capacitor) del gioco Overlight. Il gioco è un unico file HTML in `www/index.html`
(build release, senza Playgama Bridge, senza schermo intero, tutto offline).

## APK di prova (Android)
- **Su GitHub**: Actions → "APK di prova (Android)" → Run workflow. A fine job scarichi `overlight-debug-apk` dagli artifacts.
- **Sul tuo computer** (servono Node 22, JDK 21 e Android SDK): `bash scripts/make-android.sh && cd android && ./gradlew assembleDebug`
  → `android/app/build/outputs/apk/debug/app-debug.apk`. Per installarlo: `adb install -r app-debug.apk` oppure copia il file sul telefono.

## Stato
- Pubblicità: nell'app il Bridge non c'è, quindi il video premiato è ancora simulato. AdMob (solo ID di test) è il passo successivo.
- Classifiche: nascoste (il pulsante compare solo se il Bridge le supporta): da verificare sul telefono.
- Da verificare su telefono vero: notch/aree sicure, salvataggi (localStorage), audio, controlli a due levette.
