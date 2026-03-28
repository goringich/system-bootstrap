#!/usr/bin/env bash
set -euo pipefail

config="${HOME}/.config/rofi/config-appscope-launcher.rasi"

if pgrep -x rofi >/dev/null 2>&1; then
  pkill rofi
  exit 0
fi

current_name="$(pactl get-default-sink 2>/dev/null || true)"

menu_entries="$(
  python3 - <<'PY'
import subprocess

short = subprocess.run(
    ["pactl", "list", "short", "sinks"],
    check=True,
    text=True,
    capture_output=True,
).stdout.splitlines()

verbose = subprocess.run(
    ["pactl", "list", "sinks"],
    check=True,
    text=True,
    capture_output=True,
).stdout

desc_by_name = {}
current_name = None
for line in verbose.splitlines():
    stripped = line.strip()
    if stripped.startswith("Name:"):
        current_name = stripped.split("Name:", 1)[1].strip()
    elif stripped.startswith("Description:") and current_name:
        desc_by_name[current_name] = stripped.split("Description:", 1)[1].strip()

for line in short:
    parts = line.split("\t")
    if len(parts) < 2:
        continue
    sink_id, sink_name = parts[0], parts[1]
    description = desc_by_name.get(sink_name, sink_name)
    print(f"{sink_id}\t{sink_name}\t{description}")
PY
)"

[[ -n "${menu_entries}" ]] || {
  notify-send "Audio" "No output devices found"
  exit 1
}

selection="$(
  while IFS=$'\t' read -r sink_id sink_name sink_desc; do
    prefix=" "
    if [[ "${sink_name}" == "${current_name}" ]]; then
      prefix="*"
    fi
    printf "%s %s  [%s]\n" "${prefix}" "${sink_desc}" "${sink_id}"
  done <<<"${menu_entries}" | \
    rofi -dmenu -i -p "Audio Output" -mesg "Choose the default output device" -config "${config}"
)"

[[ -n "${selection:-}" ]] || exit 0

selected_id="$(grep -oE '\[[0-9]+\]$' <<<"${selection}" | tr -d '[]' || true)"
[[ -n "${selected_id}" ]] || exit 1

selected_name="$(awk -F'\t' -v target="${selected_id}" '$1 == target {print $2}' <<<"${menu_entries}")"
selected_desc="$(awk -F'\t' -v target="${selected_id}" '$1 == target {print $3}' <<<"${menu_entries}")"
[[ -n "${selected_name}" ]] || exit 1

pactl set-default-sink "${selected_name}"

while read -r input_id _; do
  [[ -n "${input_id}" ]] || continue
  pactl move-sink-input "${input_id}" "${selected_name}" >/dev/null 2>&1 || true
done < <(pactl list short sink-inputs 2>/dev/null || true)

notify-send "Audio" "Default output: ${selected_desc}"
