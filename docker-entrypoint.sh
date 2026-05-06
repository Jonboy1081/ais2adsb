#!/bin/sh
set -e

: "${UPD_IN_PORT:=9000}"

if [ -z "${SBS_TARGET_HOST}" ]; then
    echo "FATAL: SBS_TARGET_HOST not defined" >&2
    exit 1
fi
if [ -z "${SBS_TARGET_PORT}" ]; then
    echo "FATAL: SBS_TARGET_PORT not defined" >&2
    exit 1
fi

bool_flag() {
    # $1 = env value, $2 = base flag name (e.g. "ships" -> --ships / --no-ships)
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on|enabled) printf -- "--%s" "$2" ;;
        0|false|no|off|disabled) printf -- "--no-%s" "$2" ;;
        "") printf "" ;;
        *) printf -- "--no-%s" "$2" ;;
    esac
}

mkdir -p /data

set -- \
    0.0.0.0 "${UPD_IN_PORT}" \
    "${SBS_TARGET_HOST}" "${SBS_TARGET_PORT}" \
    --save-file /data/ais2adsb.map \
    --map-file /data/ais2adsb.map

[ -n "${INCLUDE_SAR}" ]   && set -- "$@" $(bool_flag "${INCLUDE_SAR}" sar)
[ -n "${INCLUDE_SHIPS}" ] && set -- "$@" $(bool_flag "${INCLUDE_SHIPS}" ships)
[ -n "${CALLSIGN}" ]      && set -- "$@" $(bool_flag "${CALLSIGN}" callsign)
[ -n "${METRICS_PORT}" ]  && set -- "$@" --metrics-port "${METRICS_PORT}"

exec python3 /usr/local/bin/ais2adsb.py "$@"
