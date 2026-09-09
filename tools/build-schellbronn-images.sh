#!/usr/bin/env bash
#
# build-schellbronn-images.sh
#
# Erzeugt die WebP-Galerie fuer den Erinnerungsgarten Schellbronn.
#
# Anders als die uebrigen Bilder der Seite werden diese NICHT base64 in
# index.html eingebettet, sondern als echte Dateien ausgeliefert. Eine
# Galerie dieser Groesse wuerde inline die Ladezeit der gesamten
# Single-File-Seite belasten - auch fuer Besucher, die die Galerie nie
# oeffnen.
#
# Pro Quellbild entstehen zwei Dateien:
#   schellbronn-NN-thumb.webp   max. 800 px lange Kante   (Grid)
#   schellbronn-NN.webp         max. 1800 px lange Kante  (Lightbox)
#
# EXIF/XMP/ICC inklusive GPS werden verworfen (cwebp -metadata none ist
# ohnehin die Voreinstellung, hier zur Sicherheit explizit gesetzt).
#
# Aufruf:
#   tools/build-schellbronn-images.sh [QUELLORDNER]
#
# Voraussetzung: cwebp (brew install webp)

set -euo pipefail

SRC="${1:-$HOME/Desktop/Schellbronn/OneDrive_1_4.9.2026}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/bilder/schellbronn"

THUMB_MAX=800
FULL_MAX=1800
QUALITY=80

if ! command -v cwebp >/dev/null 2>&1; then
  echo "cwebp nicht gefunden. Installation: brew install webp" >&2
  exit 1
fi

if [ ! -d "$SRC" ]; then
  echo "Quellordner nicht gefunden: $SRC" >&2
  exit 1
fi

mkdir -p "$OUT"

# Laengere Kante auf MAX begrenzen, kuerzere proportional.
# cwebp -resize erwartet Zielbreite/-hoehe; 0 heisst "proportional".
resize_args() {
  local w="$1" h="$2" max="$3"
  if [ "$w" -ge "$h" ]; then
    if [ "$w" -le "$max" ]; then echo ""; else echo "-resize $max 0"; fi
  else
    if [ "$h" -le "$max" ]; then echo ""; else echo "-resize 0 $max"; fi
  fi
}

n=0
# Sortiert einlesen, damit die Nummerierung reproduzierbar ist.
while IFS= read -r src; do
  n=$((n + 1))
  num=$(printf "%02d" "$n")

  w=$(sips -g pixelWidth  "$src" | awk -F': ' '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$src" | awk -F': ' '/pixelHeight/{print $2}')

  # shellcheck disable=SC2046
  cwebp -quiet -q "$QUALITY" -metadata none \
        $(resize_args "$w" "$h" "$FULL_MAX") \
        "$src" -o "$OUT/schellbronn-$num.webp"

  # shellcheck disable=SC2046
  cwebp -quiet -q "$QUALITY" -metadata none \
        $(resize_args "$w" "$h" "$THUMB_MAX") \
        "$src" -o "$OUT/schellbronn-$num-thumb.webp"

  tw=$(sips -g pixelWidth  "$OUT/schellbronn-$num-thumb.webp" | awk -F': ' '/pixelWidth/{print $2}')
  th=$(sips -g pixelHeight "$OUT/schellbronn-$num-thumb.webp" | awk -F': ' '/pixelHeight/{print $2}')

  printf "schellbronn-%s  thumb %sx%s  (%s)\n" \
    "$num" "$tw" "$th" "$(basename "$src")"
done < <(find "$SRC" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | sort)

echo
echo "Thumbnails: $(du -ch "$OUT"/*-thumb.webp | tail -1 | cut -f1)"
echo "Gesamt:     $(du -sh "$OUT" | cut -f1)  ($n Bilder, $((n * 2)) Dateien)"
