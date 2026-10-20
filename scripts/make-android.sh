#!/usr/bin/env bash
# Genera il progetto Android (Capacitor) a partire da www/ e applica le impostazioni dell'app:
# orizzontale fisso, schermo intero immersivo, area notch. Uso: bash scripts/make-android.sh
set -euo pipefail
cd "$(dirname "$0")/.."

npm install
[ -d android ] || npx cap add android
npx cap sync android

APP=android/app/src/main
MAN=$APP/AndroidManifest.xml
# orizzontale fisso (sensore: entrambi i versi)
grep -q 'screenOrientation' "$MAN" || sed -i 's#<activity#<activity android:screenOrientation="sensorLandscape"#' "$MAN"

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
