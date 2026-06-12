#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/android/app/src/main"
OUT="$ROOT/android/build"
SDK="${ANDROID_SDK:-/opt/homebrew/share/android-commandlinetools}"
BUILD_TOOLS="$SDK/build-tools/34.0.0"
ANDROID_JAR="$SDK/platforms/android-34/android.jar"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"

AAPT2="$BUILD_TOOLS/aapt2"
D8="$BUILD_TOOLS/d8"
ZIPALIGN="$BUILD_TOOLS/zipalign"
APKSIGNER="$BUILD_TOOLS/apksigner"
JAVAC="$JAVA_HOME/bin/javac"
KEYTOOL="$JAVA_HOME/bin/keytool"

rm -rf "$OUT/intermediates"
mkdir -p "$OUT/intermediates/res" "$OUT/intermediates/gen" "$OUT/intermediates/classes" "$OUT/intermediates/dex" "$OUT/outputs"

"$AAPT2" compile --dir "$APP/res" -o "$OUT/intermediates/res/resources.zip"
"$AAPT2" link \
  -I "$ANDROID_JAR" \
  --manifest "$APP/AndroidManifest.xml" \
  -A "$APP/assets" \
  --java "$OUT/intermediates/gen" \
  --min-sdk-version 23 \
  --target-sdk-version 34 \
  -o "$OUT/intermediates/lishkod-unsigned.apk" \
  "$OUT/intermediates/res/resources.zip"

"$JAVAC" \
  -encoding UTF-8 \
  -source 17 \
  -target 17 \
  -classpath "$ANDROID_JAR" \
  -d "$OUT/intermediates/classes" \
  $(find "$APP/java" "$OUT/intermediates/gen" -name '*.java' -print)

"$D8" \
  --lib "$ANDROID_JAR" \
  --output "$OUT/intermediates/dex" \
  $(find "$OUT/intermediates/classes" -name '*.class' -print)

cp "$OUT/intermediates/lishkod-unsigned.apk" "$OUT/intermediates/lishkod-with-dex.apk"
(cd "$OUT/intermediates/dex" && zip -qr "$OUT/intermediates/lishkod-with-dex.apk" classes.dex)

"$ZIPALIGN" -f -p 4 "$OUT/intermediates/lishkod-with-dex.apk" "$OUT/intermediates/lishkod-aligned.apk"

KEYSTORE="$OUT/lishkod-debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
  "$KEYTOOL" -genkeypair \
    -keystore "$KEYSTORE" \
    -storepass android \
    -keypass android \
    -alias lishkod \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Lishkod Debug,O=Lishkod,C=IL"
fi

"$APKSIGNER" sign \
  --ks "$KEYSTORE" \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$OUT/outputs/lishkod-debug.apk" \
  "$OUT/intermediates/lishkod-aligned.apk"

"$APKSIGNER" verify "$OUT/outputs/lishkod-debug.apk"
echo "$OUT/outputs/lishkod-debug.apk"
