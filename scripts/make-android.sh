#!/usr/bin/env bash
# Genera il progetto Android (Capacitor) a partire da www/ e applica le impostazioni dell'app:
# orizzontale fisso, schermo intero immersivo, area notch. Uso: bash scripts/make-android.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# gioco per l'app = release del gioco (game/index.html) + modifiche dell'app (app/admob-block.js)
python3 scripts/build-www.py game/index.html www/index.html

npm install
[ -d android ] || npx cap add android
npx cap sync android
python3 scripts/patch-gradle.py   # API 36, versione e firma per Google Play

APP=android/app/src/main
MAN=$APP/AndroidManifest.xml
# orizzontale fisso (sensore: entrambi i versi)
grep -q 'screenOrientation' "$MAN" || sed -i 's#<activity#<activity android:screenOrientation="sensorLandscape"#' "$MAN"

# AdMob: App ID di Overlight nel manifest (obbligatorio, altrimenti l'app si chiude all'avvio)
grep -q 'com.google.android.gms.ads.APPLICATION_ID' "$MAN" || sed -i 's#</application>#    <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-6445940059153239~2146036708"/>\n    </application>#' "$MAN"
grep -q 'ca-app-pub-6445940059153239~2146036708' "$MAN" || { echo "ERRORE: App ID AdMob non inserito nel manifest"; exit 1; }

# Icona dell'app: sostituisce le icone predefinite di Capacitor con quelle in icon/android-res
RES=$APP/res
find "$RES" -name 'ic_launcher*' -type f -delete
rm -f "$RES"/drawable*/ic_launcher_foreground.xml "$RES"/values/ic_launcher_background.xml
cp -r icon/android-res/. "$RES"/

# MainActivity: schermo intero immersivo + contenuto sotto il notch
PKG_DIR=$(dirname "$(find "$APP/java" -name MainActivity.java | head -1)")
PKG=$(echo "${PKG_DIR#$APP/java/}" | tr '/' '.')
cat > "$PKG_DIR/MainActivity.java" <<JAVA
package $PKG;

import android.os.Build;
import android.os.Bundle;
import android.view.WindowManager;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    if (Build.VERSION.SDK_INT >= 28) {
      getWindow().getAttributes().layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
    }
    hideBars();
  }

  @Override
  public void onWindowFocusChanged(boolean hasFocus) {
    super.onWindowFocusChanged(hasFocus);
    if (hasFocus) hideBars();
  }

  private void hideBars() {
    WindowInsetsControllerCompat c = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
    c.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
    c.hide(WindowInsetsCompat.Type.systemBars());
  }
}
JAVA
echo "Progetto Android pronto in ./android (package $PKG)"
