#!/bin/ash
# Sets a deterministic guest Wi-Fi key and generates a QR code (SVG).

GUEST_WIFI_SSID="SSID HERE"
SALT="SALT HERE"

# Rotation granularity: "hour" or "day"
ROTATION="day"

# Optional: pass an explicit timestamp as $1 (e.g. 2025090715 for hour, 20250907 for day)
OVERRIDE_TS="$1"

# --- helpers ---

derive_timestamp() {
  if [ -n "$OVERRIDE_TS" ]; then
    echo "$OVERRIDE_TS"
    return
  fi
  if [ "$ROTATION" = "day" ]; then
    date +%Y%m%d
  else
    # default: hour
    date +%Y%m%d%H
  fi
}

derive_key() {
  # Input: SALT + TIMESTAMP -> hex SHA256 -> first 16 chars (8ÔÇô63 required; 16 is fine?)
  # BusyBox sha256sum is usually present on OpenWrt; else: opkg install coreutils-sha256sum
  local material="${SALT}$1"
  echo -n "$material" | sha256sum | awk '{print $1}' | cut -c1-24
}

escape_qr_field() {
  # Escape characters per Wi-Fi QR ÔÇ£WIFI:ÔÇªÔÇØ needs: \ ; , : "
  # BusyBox sed is fine.
  printf '%s' "$1" \
  | sed -e 's/\\/\\\\/g' -e 's/;/\\;/g' -e 's/:/\\:/g' -e 's/,/\\,/g' -e 's/"/\\"/g'
}

reload_wifi() {
  if command -v wifi >/dev/null 2>&1; then
    # On newer OpenWrt, "wifi reload" exists; fallback to "wifi"
    wifi reload 2>/dev/null || wifi
  else
    /etc/init.d/network reload
  fi
}

# --- main ---

TIMESTAMP="$(derive_timestamp)"
WIFI_KEY="$(derive_key "$TIMESTAMP")"

SSID_ESC="$(escape_qr_field "$GUEST_WIFI_SSID")"
KEY_ESC="$(escape_qr_field "$WIFI_KEY")"
QR_WIFI_STRING="WIFI:S:${SSID_ESC};T:WPA;P:${KEY_ESC};;"

# Count iface sections safely and loop only through existing ones
IFACE_COUNT="$(uci -q show wireless | grep -c '=wifi-iface')"
[ -z "$IFACE_COUNT" ] && IFACE_COUNT=0

i=0
FOUND=0
while [ "$i" -lt "$IFACE_COUNT" ]; do
  SSID_VAL="$(uci -q get wireless.@wifi-iface[$i].ssid 2>/dev/null || echo '')"
  if [ "x$SSID_VAL" = "x$GUEST_WIFI_SSID" ]; then
    FOUND=1
    uci set wireless.@wifi-iface[$i].key="$WIFI_KEY"
  fi
  i=$((i+1))
done

if [ "$FOUND" -eq 0 ]; then
  echo "No wifi-iface with SSID '$GUEST_WIFI_SSID' found. Aborting." >&2
  exit 1
fi

uci commit wireless
reload_wifi

# Generate QR (SVG). If qrencode is missing: opkg update && opkg install qrencode
OUT="/tmp/current_guest_wifi_pw.svg"
if command -v qrencode >/dev/null 2>&1; then
  qrencode -t svg -l h -o "$OUT" "$QR_WIFI_STRING"
  echo "Applied key '$WIFI_KEY' to SSID '$GUEST_WIFI_SSID'."
  echo "QR saved to: $OUT"
else
  echo "Applied key '$WIFI_KEY' to SSID '$GUEST_WIFI_SSID'."
  echo "qrencode not found; install with: opkg update && opkg install qrencode"
  echo "QR payload: $QR_WIFI_STRING"
fi
