# ais2adsb

This  Python script converts AIS NMEA lines received over UDP to BaseStation [format](http://woodair.net/sbs/article/barebones42_socket_data.htm) and sends it to a specified server e.g. Virtual Radar Server (VRS). Main purpose is to plot data on SAR aircraft picked up by AIS receivers in ADS-B plotting software.  The following is an example of a SAR helicopter broadcasting AIS messages plotted in VRS using AIS messages converted by ais2adsb (courtesy of jonboy1081):

<img width="251" alt="image" src="https://user-images.githubusercontent.com/52420030/220178667-2196cc3d-be5d-4194-a9c3-8d37ac08f672.png">

And plotted using the ADS-B data:

<img width="251" alt="image" src="https://user-images.githubusercontent.com/52420030/220178717-199a5d36-ae7e-4d50-9ef8-931759c1085a.png">

This is a nice example where sometimes AIS has better reception than ADS-B. The idea for this tool came from [flygfantast](https://github.com/jvde-github/AIS-catcher/discussions/73) and jonboy1081.

## Usage
```
usage: ais2adsb [-h] [--sar | --no-sar] [--ships | --no-ships]
                [--callsign | --no-callsign] [--print-dict]
                [--map-file MAP_FILE] [--save-file SAVE_FILE]
                [--metrics-port METRICS_PORT] [--no-default-map] [--version]
                udp_ip udp_port sbs_ip sbs_port
```
Minimal invocation:
```
python3 ./ais2adsb.py 192.168.1.235 4002 192.168.1.239 30003
```
reads AIS messages on `192.168.1.235:4002/udp` and forwards converted SBS to VRS at `192.168.1.239:30003/tcp`. Defaults: `--sar` on, `--ships` off, `--callsign` on.

If your receiver is AIS-catcher, send to ais2adsb via its `-u` option:
```
AIS-catcher -u 192.168.1.235 4002 .....
```

The `--map-file` option reads a Python-dict-literal mapping of MMSI → 24-bit ICAO from disk; `--save-file` writes the live map back periodically and on exit. A bundled default mapping ships in `data/icao_map.dict` and loads automatically (disable with `--no-default-map`). For unknown MMSIs ais2adsb auto-generates ICAO codes of the form `0xFxxxxx` derived from the MMSI's lower 20 bits.

A full example, also exposing Prometheus metrics on port 8080:
```
python3 ./ais2adsb.py 192.168.1.235 4002 192.168.1.239 30003 \
    --ships --map-file mapping.dict --print-dict --no-callsign --metrics-port 8080
```

## Docker

The included `docker-compose.yml` configures the container via environment variables:

| Variable | Default | Notes |
|---|---|---|
| `SBS_TARGET_HOST` | _required_ | TCP host for SBS output |
| `SBS_TARGET_PORT` | _required_ | TCP port for SBS output |
| `UPD_IN_PORT` | `9000` | UDP port the container listens on for NMEA |
| `INCLUDE_SAR` | _on_ | `true`/`false` — include SAR aircraft |
| `INCLUDE_SHIPS` | _off_ | `true`/`false` — include vessels |
| `CALLSIGN` | _on_ | `true`/`false` — emit generated callsigns |
| `METRICS_PORT` | _disabled_ | exposes `/metrics` (Prometheus) and `/health` |

State (the live MMSI→ICAO map) persists to `/data/ais2adsb.map`.

### Metrics and health

When `--metrics-port`/`METRICS_PORT` is set, ais2adsb starts an HTTP server exposing two endpoints:

`GET /metrics` — Prometheus text format (version 0.0.4):

| Metric | Type | Description |
|---|---|---|
| `ais2adsb_messages_received_total` | counter | UDP datagrams received |
| `ais2adsb_messages_decoded_total` | counter | Messages decoded by aiscat (multipart reassembled) |
| `ais2adsb_messages_sent_total` | counter | SBS position records sent upstream |
| `ais2adsb_tcp_reconnects_total` | counter | Successful TCP connections to SBS server (incl. initial) |
| `ais2adsb_last_message_timestamp_seconds` | gauge | Unix timestamp of the most recent UDP receive |
| `ais2adsb_last_send_timestamp_seconds` | gauge | Unix timestamp of the most recent SBS send |
| `ais2adsb_unique_icaos` | gauge | Size of the active MMSI→ICAO map |
| `ais2adsb_connected` | gauge | `1` if currently connected to the SBS server, else `0` |

`GET /health` — `200 ok` if connected to the SBS server *and* a UDP message was received in the last 300 s. `503 degraded` otherwise. Use this for container healthchecks or load-balancer probes.

## Installation

For Windows users who do not have Python installed there is a package available in the Releases section, built via [pyinstaller](https://pyinstaller.org/en/stable/).

For other platforms, the simplest path is Python 3.9+ with [aiscat](https://pypi.org/project/aiscat/):
```
sudo apt install python3 pip
pip3 install aiscat
git clone https://github.com/jvde-github/ais2adsb.git
cd ais2adsb
```

Set up for example VRS so that it can receive BaseStation messages as a TCP server:
<img width="659" alt="image" src="https://user-images.githubusercontent.com/52420030/219872223-2d199476-94e4-467c-9943-3cab66e48c4a.png">

The NMEA input should be sent over UDP. Most AIS software including AIS-catcher can easily be set up to achieve this. Assuming a stream is arriving on `192.168.1.235:4002`:
```
python3 ./ais2adsb.py 192.168.1.235 4002 192.168.1.239 30003
```
where `192.168.1.239` is the PC running VRS. This forwards SAR aircraft only by default. To include ship positions:
```
python3 ./ais2adsb.py 192.168.1.235 4002 192.168.1.239 30003 --ships
```

You will see in the VRS main window that the client has connected and hopefully some messages have been sent as well:
<img width="552" alt="image" src="https://user-images.githubusercontent.com/52420030/219874149-dd0458dd-d804-4fde-9f2e-cf7812f58d3c.png">

The final output in the webinterface of VRS will look something like:
<img width="1232" alt="image" src="https://user-images.githubusercontent.com/52420030/219868349-5b1dc1e5-33b1-48a0-96a4-9ad4bb49134f.png">

## ICAO mapping

A bundled default mapping (~280 entries, kindly provided by jonboy1081 and flygfantast) ships in [`data/icao_map.dict`](data/icao_map.dict) and is loaded automatically. Pass `--no-default-map` to skip it. Custom mappings via `--map-file` use the same format — a Python-dict literal of `{mmsi: icao_int}`:
```python
{
    111232512: 0x406C79,
    111232511: 0x406C82,
    250002898: 0x4CA98D,
    # ...
}
```
Unknown MMSIs are auto-assigned ICAO codes of the form `0xFxxxxx` derived from the MMSI's lower 20 bits, with collision-avoidance against existing entries. Use `--save-file PATH` to persist the live (default + auto-assigned) map to disk; the same path can be reloaded next run via `--map-file PATH`.

## Development

```
python3 -m pip install aiscat
python3 -m unittest discover tests
```

CI runs the unit tests on every push/PR ([`.github/workflows/python-ci.yml`](.github/workflows/python-ci.yml)). Docker images are built for `linux/amd64`, `linux/arm64`, and `linux/arm/v7` ([`.github/workflows/docker-image.yml`](.github/workflows/docker-image.yml)) and published to GHCR — armv7 covers Pi 1/2/3 in 32-bit mode and similar boards.

## Changes

Recent substantive changes (vs. earlier `0.14`-era versions):

- **Decoder** — switched from `pyais` to [`aiscat`](https://pypi.org/project/aiscat/). Multipart AIVDM groups are now reassembled (previously raised and were dropped). AIS sentinel values for "speed not available" are correctly mapped to `None` instead of being passed through as `102.3` knots.
- **Altitude bug fix (SAR)** — AIS type 9 altitude is in metres; the SBS BaseStation field is feet. Earlier versions emitted the raw metric value, plotting helicopters at ~30 % of their true altitude in VRS. Now converted with the `4095 = N/A` sentinel handled.
- **Position sanity** — lat/lon are range-checked (`-90..90`, `-180..180`) so AIS sentinels (`lat=91`, `lon=181`) can no longer bleed through to ADS-B viewers as ghost positions at the North Pole.
- **Graceful shutdown** — `SIGTERM` (used by `docker stop`) now triggers the same dictionary-save path as `SIGINT`.
- **CLI** — replaced the positional `SHIPS on` style with `argparse`. New flags: `--ships/--no-ships`, `--sar/--no-sar`, `--callsign/--no-callsign`, `--map-file`, `--save-file`, `--print-dict`, `--metrics-port`, `--no-default-map`, `--version`.
- **ICAO mapping** — extracted from the script body into [`data/icao_map.dict`](data/icao_map.dict).
- **Metrics / health** — see *Metrics and health* above.
- **Docker** — base image swapped to `python:3.13-slim` (~215 MB). Multi-arch build covers amd64 / arm64 / armv7.
- **Tests** — unit tests under `tests/` cover the alt conversion (incl. sentinel), ICAO generation, filter logic, CLI parsing, and `sendBaseStation` rejection of bogus positions.

### Migrating from older versions

**If you run the script directly (Python / pyinstaller / launch scripts):**

1. Replace `pyais` with `aiscat`:
   ```
   pip3 uninstall pyais        # optional, can coexist
   pip3 install aiscat
   ```
2. Update the command line — the old positional `KEY value` style was removed in favour of `argparse`. Translation table:

   | Old | New |
   |---|---|
   | `SHIPS on` / `SHIPS off` | `--ships` / `--no-ships` |
   | `SAR on` / `SAR off` | `--sar` / `--no-sar` |
   | `CALLSIGN on` / `CALLSIGN off` | `--callsign` / `--no-callsign` |
   | `PRINT on` | `--print-dict` |
   | `FILE path.dict` | `--map-file path.dict` |
   | `SAVE path.dict` | `--save-file path.dict` |

   So:
   ```
   # Before
   python3 ais2adsb.py 192.168.1.235 4002 192.168.1.239 30003 SHIPS on FILE map.dict CALLSIGN off
   # After
   python3 ais2adsb.py 192.168.1.235 4002 192.168.1.239 30003 --ships --map-file map.dict --no-callsign
   ```
3. The saved-dict file format is unchanged — your existing `*.dict` files keep working with `--map-file`.
4. SBS output bytes are identical to the previous version for any message both libraries handled. You should not need to reconfigure VRS.
5. **One-off cleanup if you previously saw weird positions:** if you noticed AIS targets plotted near the North Pole or SAR helicopters at impossibly low altitudes, those were the bugs fixed in this release — no action needed, just expect cleaner output going forward.

**If you run the Docker image (`ghcr.io/jvde-github/ais2adsb:edge`):**

The image tag is unchanged. The `docker-compose.yml` env-var names (`SBS_TARGET_HOST`, `SBS_TARGET_PORT`, `INCLUDE_SHIPS`, `CALLSIGN`, `UPD_IN_PORT`) are unchanged and continue to work — just `docker pull` the new image. Two optional additions: `INCLUDE_SAR` (defaults to on) and `METRICS_PORT` (off unless set). The `/data` volume layout is unchanged, so your persistent `ais2adsb.map` carries over.

**If you build from the Dockerfile yourself:** the base image swapped from `ghcr.io/sdr-enthusiasts/docker-baseimage:python` to `python:3.13-slim`. The `rootfs/` directory was removed (s6 service files no longer needed); behaviour is now provided by [`docker-entrypoint.sh`](docker-entrypoint.sh).
