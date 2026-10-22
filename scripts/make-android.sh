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

# Google Play Games Services: ID applicazione (Play Console > Play Games Services) come risorsa + meta-data nel manifest
cat > $APP/res/values/games-ids.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_id" translatable="false">634559174407</string>
</resources>
XML
grep -q 'com.google.android.gms.games.APP_ID' "$MAN" || sed -i 's#</application>#    <meta-data android:name="com.google.android.gms.games.APP_ID" android:value="@string/app_id"/>\n    </application>#' "$MAN"
grep -q 'com.google.android.gms.games.APP_ID' "$MAN" || { echo "ERRORE: APP_ID Play Games non inserito nel manifest"; exit 1; }

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
import com.google.android.gms.games.PlayGamesSdk;

public class MainActivity extends BridgeActivity {
  @Override
  public void onCreate(Bundle savedInstanceState) {
    registerPlugin(PlayGamesPlugin.class);
    super.onCreate(savedInstanceState);
    PlayGamesSdk.initialize(this);
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
cat > "$PKG_DIR/PlayGamesPlugin.java" <<JAVA
package $PKG;

import android.content.Intent;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.android.gms.games.GamesSignInClient;
import com.google.android.gms.games.PlayGames;

@CapacitorPlugin(name = "PlayGames")
public class PlayGamesPlugin extends Plugin {
  @PluginMethod
  public void signIn(final PluginCall call) {
    final GamesSignInClient c = PlayGames.getGamesSignInClient(getActivity());
    c.isAuthenticated().addOnCompleteListener(t -> {
      if (t.isSuccessful() && t.getResult().isAuthenticated()) { done(call, true); return; }
      c.signIn().addOnCompleteListener(t2 -> done(call, t2.isSuccessful() && t2.getResult().isAuthenticated()));
    });
  }

  private void done(PluginCall call, boolean ok) {
    JSObject r = new JSObject();
    r.put("signedIn", ok);
    call.resolve(r);
  }

  @PluginMethod
  public void submitScore(final PluginCall call) {
    String id = call.getString("id");
    long score = call.getData().optLong("score", 0);
    if (id == null || score <= 0) { call.resolve(); return; }
    PlayGames.getLeaderboardsClient(getActivity()).submitScore(id, score);
    call.resolve();
  }

  @PluginMethod
  public void showLeaderboard(final PluginCall call) {
    String id = call.getString("id");
    if (id == null) { call.reject("id mancante"); return; }
    PlayGames.getLeaderboardsClient(getActivity()).getLeaderboardIntent(id)
      .addOnSuccessListener(intent -> { getActivity().startActivityForResult(intent, 9004); call.resolve(); })
      .addOnFailureListener(e -> call.reject("classifica non disponibile"));
  }
}
JAVA
echo "Progetto Android pronto in ./android (package $PKG)"
