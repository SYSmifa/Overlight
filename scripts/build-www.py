#!/usr/bin/env python3
"""Costruisce www/index.html (gioco per l'app) a partire dalla versione RELEASE del gioco.

Uso: python3 scripts/build-www.py game/index.html www/index.html

Per aggiornare il gioco nell'app basta sostituire game/index.html con la nuova release (stesso file di Playgama):
questo script rimette da solo le modifiche dell'app (niente Playgama, schermo intero, AdMob + consenso + pulsante PRIVACY).
Se il gioco e' cambiato proprio in uno dei punti toccati, lo script si ferma e dice quale.
"""
import re, sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding='utf-8').read()
block = open('app/admob-block.js', encoding='utf-8').read() + open('app/splash-block.js', encoding='utf-8').read()

def once(text, old, new, what):
    if text.count(old) != 1:
        sys.exit(f"ERRORE build-www: punto non trovato (o ripetuto) nel gioco: {what}")
    return text.replace(old, new)

# 1. niente Playgama Bridge (il gioco gira da solo, offline)
s = once(s, '<!-- Playgama Bridge SDK (ads, saves, platform events). If it cannot load, the game still runs offline (localStorage, simulated ads). -->\n', '', 'commento Playgama')
s = once(s, '<script src="https://bridge.playgama.com/v2/stable/playgama-bridge.js"></script>\n', '', 'script Playgama')
# 2. schermo intero: nell'app e' gia' a schermo intero
s = once(s, "const fsCan = (() => { try { return !!(document.fullscreenEnabled || document.webkitFullscreenEnabled); } catch (e) { return false; } })();",
         "const fsCan = false;   // app build: Capacitor is already fullscreen", 'fsCan')
# 3. blocco AdMob + collegamento
marker = '/* ---------- ads: Playgama Bridge when it is there, a simulated video otherwise ---------- */'
s = once(s, marker, block + marker, 'inizio blocco ADS')
s = once(s, "bridge() { const B = window.bridge; return PG.on && B && B.advertisement ? B : null; },",
         "bridge() { const B = window.bridge; return PG.on && B && B.advertisement ? B : AM.shim; },   // Playgama, else AdMob in the app, else null (simulated video)", 'ADS.bridge')
old = "  } else uiButton(CX - bw / 2, by + bh + gap * 3 + UI.h() * 2, bw, UI.h(), 'LANGUAGES', C.uiBlue, () => { menu.screen = 'lang'; }, { size: FS * 0.95 });"
new = """  } else if (AM.privacy) {   // the app, in a region that asks for it (EEA / UK / some US states): a way back to the privacy choices
    const hw = (bw - gap) / 2, ry = by + bh + gap * 3 + UI.h() * 2;
    uiButton(CX - bw / 2, ry, hw, UI.h(), 'LANGUAGES', C.uiBlue, () => { menu.screen = 'lang'; }, { size: FS * 0.85 });
    uiButton(CX + gap / 2, ry, hw, UI.h(), 'PRIVACY', C.uiBlue, () => AM.openPrivacy(), { size: FS * 0.85 });
""" + old.replace('  } else uiButton', '  } else uiButton', 1)
s = once(s, old, new, 'pulsante LANGUAGES del menu')
s = once(s, "initPlatform().then(loadSaves).catch(() => {}).then(() => {",
         "if (AM.start) AM.start();   // app only: consent form + AdMob start\ninitPlatform().then(loadSaves).catch(() => {}).then(() => {", 'avvio piattaforma')
# 6. splash (OVERLIGHT + logo studio) prima del menu
s = once(s, "if (state === 'title') { if (bootReady) drawMenu(); else vtext('LOADING...'",
         "if (state === 'title') { if (SPLASH.on()) SPLASH.draw(); else if (bootReady) drawMenu(); else vtext('LOADING...'", 'disegno del menu')
# 7. annunci reali solo se richiesto (OVERLIGHT_LIVE_ADS=1, build da pubblicare); altrimenti solo annunci di test
import os
if os.environ.get('OVERLIGHT_LIVE_ADS') == '1':
    s = once(s, 'const TESTING = true;', 'const TESTING = false;', 'interruttore annunci di test')
    print('ATTENZIONE: annunci REALI attivi')
open(dst, 'w', encoding='utf-8').write(s)
print('www pronto:', dst)
