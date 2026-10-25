#!/usr/bin/env bash
# weather.sh — one shot, one weather reading from Open-Meteo (no API key).
#
#   <location>  "City, Country" or "lat,lon"   (argv 1)
#   <units>     auto | metric | imperial       (argv 2)
#
# Prints one JSON block on success only; prints NOTHING on any failure, so the
# QML keeps its last good reading. Nothing here evals, and the only dynamic
# values that reach a command line pass through `--data-urlencode`, so a
# hostile config value cannot become a URL parameter or a shell command.
#
# Units follow the place: the geocoder returns a country code, and `auto`
# answers with the convention of that country — °F / mph / inHg for US, Liberia
# and Myanmar, °C / km/h / hPa everywhere else. `metric` / `imperial` force a
# side for the config. Pressure is hPa from the API on every side, so imperial
# converts it to inHg here.
set -u

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/tokyonight"
GEO_API="https://geocoding-api.open-meteo.com/v1/search"
FC_API="https://api.open-meteo.com/v1/forecast"

# ---------- boundary: argv ----------
[ "$#" -eq 2 ] || exit 0
LOCATION="$1"
UNITS="$2"
case "$UNITS" in
    auto|metric|imperial) ;;
    *) exit 0 ;;
esac

# Allow characters that can be part of a real place name — ASCII letters,
# digits, space, ., , ' - / ( ) _ — plus any high byte (UTF-8 letters in
# non-ASCII city names). Everything else — control bytes and every shell or
# URL metacharacter — fails the script silently.
if ! printf '%s' "$LOCATION" | LC_ALL=C grep -Pq '^[A-Za-z0-9 .,\x27\-/()_\x80-\xFF]{1,80}$'; then
    exit 0
fi

mkdir -p "$CACHE" || exit 0

# ---------- geocode: "lat,lon" needs no lookup; a name is cached a day ----------
if [[ "$LOCATION" =~ ^-?[0-9]+(\.[0-9]+)?,[[:space:]]*-?[0-9]+(\.[0-9]+)?$ ]]; then
    LAT=$(printf '%s' "${LOCATION%%,*}" | tr -d '[:space:]')
    LON=$(printf '%s' "${LOCATION##*,}" | tr -d '[:space:]')
    NAME="$LOCATION"
    CN=""
else
    KEY=$(printf '%s' "$LOCATION" | md5sum | cut -d' ' -f1)
    GEO="$CACHE/weather-geo-$KEY.json"
    if ! find "$GEO" -mmin -1440 2>/dev/null | grep -q .; then
        curl -fsS --max-time 8 -G "$GEO_API" 2>/dev/null \
            --data-urlencode "name=$LOCATION" \
            --data-urlencode "count=1" \
            --data-urlencode "language=en" \
            --data-urlencode "format=json" > "$GEO.tmp" || { rm -f "$GEO.tmp"; exit 0; }
        jq -e '.results and (.results | length > 0)' "$GEO.tmp" >/dev/null 2>&1 \
            || { rm -f "$GEO.tmp"; exit 0; }
        mv "$GEO.tmp" "$GEO"
    fi
    LAT=$(jq -r '.results[0].latitude | select(type == "number")' "$GEO") || exit 0
    LON=$(jq -r '.results[0].longitude | select(type == "number")' "$GEO") || exit 0
    [ -n "$LAT" ] && [ -n "$LON" ] || exit 0
    NAME=$(jq -r '((.results[0].name // "") + ", " + (.results[0].country // "")) | rtrimstr(", ")' "$GEO" \
        | tr -d '[:cntrl:]' | cut -c1-48)
    CN=$(jq -r '.results[0].country_code // ""' "$GEO" | tr -d '[:cntrl:]')
fi

# ---------- units: auto follows the country ----------
IMPERIAL=0
if [ "$UNITS" = "imperial" ]; then
    IMPERIAL=1
elif [ "$UNITS" = "auto" ]; then
    case "$CN" in
        US|LR|MM) IMPERIAL=1 ;;
    esac
fi
TEMP_UNIT=celsius; WIND_UNIT=kmh
[ "$IMPERIAL" = 1 ] && { TEMP_UNIT=fahrenheit; WIND_UNIT=mph; }

# ---------- forecast: current + hourly, time as unix seconds ----------
FC="$CACHE/weather-fetch.json"
curl -fsS --max-time 12 -G "$FC_API" 2>/dev/null \
    --data-urlencode "latitude=$LAT" \
    --data-urlencode "longitude=$LON" \
    --data-urlencode "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,pressure_msl,wind_speed_10m" \
    --data-urlencode "hourly=temperature_2m,weather_code,is_day" \
    --data-urlencode "forecast_days=2" \
    --data-urlencode "timeformat=unixtime" \
    --data-urlencode "timezone=auto" \
    --data-urlencode "temperature_unit=$TEMP_UNIT" \
    --data-urlencode "wind_speed_unit=$WIND_UNIT" \
    > "$FC" || exit 0

# Reject a malformed or hostile payload before a single field is trusted.
jq -e '
    (.current.temperature_2m | type == "number") and
    (.current.apparent_temperature | type == "number") and
    (.current.relative_humidity_2m | type == "number") and
    (.current.pressure_msl | type == "number") and
    (.current.wind_speed_10m | type == "number") and
    (.current.weather_code | type == "number") and
    (.current.is_day == 0 or .current.is_day == 1) and
    (.hourly.time | type == "array") and
    ((.hourly.time | length) > 0) and
    ((.hourly.time | length) == (.hourly.temperature_2m | length)) and
    ((.hourly.time | length) == (.hourly.weather_code | length))
' "$FC" >/dev/null 2>&1 || exit 0

TZ=$(jq -r '.timezone // "UTC"' "$FC" | tr -d '[:cntrl:]')
case "$TZ" in
    ''|*[!A-Za-z0-9_+/-]*) TZ="UTC" ;;
esac

# ---------- pressure display: hPa for metric, inHg (×0.02953) for imperial ----------
HPA=$(jq -r '.current.pressure_msl' "$FC") || exit 0
if [ "$IMPERIAL" = 1 ]; then
    PRES_VAL=$(awk -v h="$HPA" 'BEGIN { printf "%.2f", h * 0.02953 }')
    PRES_UNIT="inHg"
else
    PRES_VAL=$(awk -v h="$HPA" 'BEGIN { printf "%.0f", h }')
    PRES_UNIT="hPa"
fi

# ---------- flow: future hours, one every 3h, up to 12, pre-formatted local
# time in the location's zone (the QML engine has no Intl / TimeZone) ----------
NOW=$(date +%s)
FLOW="$CACHE/weather-flow.json"
FLOWH="$CACHE/weather-flow-h.json"
jq -c -r --argjson now "$NOW" '
    ( [ .hourly.time | to_entries | map(select(.value > $now)) | .[0].key, 0 ][0] ) as $start
    | ( [ $start + 36, (.hourly.time | length) ] | min ) as $end
    | . as $d
    | [ range($start; $end; 3)
        | { t: $d.hourly.time[.], temp: $d.hourly.temperature_2m[.],
            code: ($d.hourly.weather_code[.] // 0), isDay: ($d.hourly.is_day[.] // 1) } ]
    | .[0:12][]' "$FC" > "$FLOW" || exit 0
: > "$FLOWH"
while IFS= read -r line; do
    t=$(printf '%s' "$line" | jq -r '.t')
    h=$(TZ="$TZ" date -d "@$t" +%H:%M 2>/dev/null) || h=""
    printf '%s' "$line" | jq -c --arg h "$h" '. + {h: $h}' >> "$FLOWH" || exit 0
done < "$FLOW"

# ---------- assemble + emit (jq escapes every string; types are re-checked) ----------
if [ "$IMPERIAL" = 1 ]; then
    TUNIT="°F"; WUNIT="mph"
else
    TUNIT="°C"; WUNIT="km/h"
fi

jq -n --slurpfile flow "$FLOWH" \
    --arg name "$NAME" \
    --arg tempUnit "$TUNIT" \
    --arg windUnit "$WUNIT" \
    --arg pressureUnit "$PRES_UNIT" \
    --argjson pressure "$PRES_VAL" \
    --argjson temp "$(jq -r '.current.temperature_2m' "$FC")" \
    --argjson feels "$(jq -r '.current.apparent_temperature' "$FC")" \
    --argjson humidity "$(jq -r '.current.relative_humidity_2m | round' "$FC")" \
    --argjson wind "$(jq -r '.current.wind_speed_10m' "$FC")" \
    --argjson code "$(jq -r '.current.weather_code' "$FC")" \
    --argjson isDay "$(jq -r '.current.is_day' "$FC")" \
    '{ ok: true, name: $name, tempUnit: $tempUnit, temp: $temp, feels: $feels,
       humidity: $humidity, pressure: $pressure, pressureUnit: $pressureUnit,
       wind: $wind, windUnit: $windUnit, code: $code, isDay: $isDay,
       flow: ($flow | map({ h: .h, temp: .temp, code: .code, isDay: .isDay })) }'