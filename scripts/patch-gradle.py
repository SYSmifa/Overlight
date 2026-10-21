#!/usr/bin/env python3
"""Prepara il progetto Android generato per Google Play: API 36, versione da variabili d'ambiente, firma di release."""
import re, sys

# 1) API di destinazione: Google Play (dal 31/8/2026) richiede almeno Android 16 = API 36
v = 'android/variables.gradle'
t = open(v).read()
for k in ('compileSdkVersion', 'targetSdkVersion'):
    m = re.search(k + r'\s*=\s*(\d+)', t)
    if not m: sys.exit(f"ERRORE patch-gradle: {k} non trovato in variables.gradle")
    cur = int(m.group(1))
    if cur < 36:
        t = t[:m.start(1)] + '36' + t[m.end(1):]
    print(f"{k}: {cur} -> {max(cur, 36)}")
open(v, 'w').write(t)

# 2) versione e firma
a = 'android/app/build.gradle'
s = open(a).read()
s, n = re.subn(r'versionCode\s+\d+', 'versionCode Integer.parseInt(System.getenv("VERSION_CODE") ?: "1")', s)
if n != 1: sys.exit("ERRORE patch-gradle: versionCode non trovato")
s, n = re.subn(r'versionName\s+"[^"]*"', 'versionName System.getenv("VERSION_NAME") ?: "1.0"', s)
if n != 1: sys.exit("ERRORE patch-gradle: versionName non trovato")
if 'signingConfigs' not in s:
    sc = '''    signingConfigs {
        release {
            if (System.getenv("KEYSTORE_FILE")) {
                storeFile file(System.getenv("KEYSTORE_FILE"))
                storePassword System.getenv("KEYSTORE_PASSWORD")
                keyAlias System.getenv("KEY_ALIAS")
                keyPassword System.getenv("KEY_PASSWORD")
            }
        }
    }
'''
    s, n = re.subn(r'([ \t]*)buildTypes\s*\{', lambda m: sc + m.group(0), s, count=1)
    if n != 1: sys.exit("ERRORE patch-gradle: buildTypes non trovato")
    s, n = re.subn(r'(buildTypes\s*\{\s*release\s*\{)', lambda m: m.group(1) + '\n            if (System.getenv("KEYSTORE_FILE")) { signingConfig signingConfigs.release }', s, count=1)
    if n != 1: sys.exit("ERRORE patch-gradle: blocco release non trovato")
open(a, 'w').write(s)
print("build.gradle pronto (versione, firma)")
