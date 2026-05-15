#!/usr/bin/env bash
set -euo pipefail

log_dir="${HOME}/__home_organized/logs"
state_dir="${HOME}/.local/state/system-watchdog"
log_file="${log_dir}/system-health.log"
state_file="${state_dir}/state.env"
vault_root="${HOME}/Desktop/Obsidian"
obsidian_dir="${vault_root}/System/System Health"
obsidian_index="${obsidian_dir}/index.md"

mkdir -p "${log_dir}" "${state_dir}" "${obsidian_dir}"

collect_desktop_incidents() {
  local boot_ref="$1"
  journalctl -b "${boot_ref}" --no-pager 2>/dev/null \
    | rg -i 'NVRM: Xid|flip event timeout|lost display notification|error while waiting for gpu progress|Process .*Hyprland.*(terminated abnormally|dumped core)|Process .*xdg-desktop-por.*(terminated abnormally|dumped core)|xdg-desktop-portal-hyprland.service: Failed with result|libaquamarine' \
    | tail -n 20 || true
}

collect_unclean_shutdown_markers() {
  journalctl -b 0 --no-pager 2>/dev/null \
    | rg -i 'corrupted or uncleanly shut down' \
    | tail -n 10 || true
}

append_block_if_present() {
  local content="$1"
  if [[ -n "${content}" ]]; then
    printf '\n```text\n%s\n```\n' "${content}"
  fi
}

trim_file() {
  local file="$1"
  local max_lines="$2"
  [[ -f "${file}" ]] || return 0
  local lines
  lines="$(wc -l < "${file}")"
  if (( lines > max_lines )); then
    tail -n "${max_lines}" "${file}" > "${file}.tmp"
    mv "${file}.tmp" "${file}"
  fi
}

ts="$(date '+%F %T %Z')"
day="$(date '+%F')"

failed_system="$(systemctl --failed --no-pager --plain --no-legend 2>/dev/null | sed '/^$/d' || true)"
failed_user="$(systemctl --user --failed --no-pager --plain --no-legend 2>/dev/null | sed '/^$/d' || true)"
boot_use="$(df --output=pcent /boot 2>/dev/null | tail -n1 | tr -dc '0-9' || echo 0)"
root_use="$(df --output=pcent / 2>/dev/null | tail -n1 | tr -dc '0-9' || echo 0)"
home_use="$(df --output=pcent /home 2>/dev/null | tail -n1 | tr -dc '0-9' || echo 0)"
journal_disk="$(journalctl --disk-usage 2>/dev/null || true)"
btrfs_scrub="$(btrfs scrub status / 2>/dev/null || true)"
boot_kernel="$(uname -r)"
current_desktop_incidents="$(collect_desktop_incidents 0)"
previous_desktop_incidents="$(collect_desktop_incidents -1)"
unclean_shutdown_markers="$(collect_unclean_shutdown_markers)"

status="ok"
reasons=()

if [[ -n "${failed_system}" ]]; then
  status="degraded"
  reasons+=("systemd system units failed")
fi
if [[ -n "${failed_user}" ]]; then
  status="degraded"
  reasons+=("systemd user units failed")
fi
if [[ -n "${current_desktop_incidents}" ]]; then
  status="degraded"
  reasons+=("current boot has Hyprland/GPU crash signals")
fi
if [[ -n "${previous_desktop_incidents}" ]]; then
  status="degraded"
  reasons+=("previous boot ended with Hyprland/GPU crash signals")
fi
if [[ -n "${unclean_shutdown_markers}" ]]; then
  status="degraded"
  reasons+=("previous shutdown was unclean")
fi
if (( boot_use >= 85 )); then
  status="degraded"
  reasons+=("/boot usage is ${boot_use}%")
fi
if (( root_use >= 90 )); then
  status="degraded"
  reasons+=("/ usage is ${root_use}%")
fi
if (( home_use >= 95 )); then
  status="degraded"
  reasons+=("/home usage is ${home_use}%")
fi
if [[ -n "${btrfs_scrub}" ]] && ! grep -qi 'Error summary:    no errors found' <<<"${btrfs_scrub}"; then
  status="degraded"
  reasons+=("btrfs scrub reports errors")
fi

reason="system health looks normal"
if (( ${#reasons[@]} > 0 )); then
  reason="$(IFS='; '; echo "${reasons[*]}")"
fi

prev_status=""
prev_reason=""
if [[ -f "${state_file}" ]]; then
  # shellcheck disable=SC1090
  source "${state_file}"
fi

printf '[%s] status=%s kernel=%s boot=%s%% root=%s%% home=%s%%\n' \
  "${ts}" "${status}" "${boot_kernel}" "${boot_use}" "${root_use}" "${home_use}" >> "${log_file}"

if [[ "${status}" != "${prev_status}" || "${reason}" != "${prev_reason}" ]]; then
  printf '[%s] detail=%s\n' "${ts}" "${reason}" >> "${log_file}"

  note_file="${obsidian_dir}/${day}.md"
  if [[ ! -f "${note_file}" ]]; then
    {
      printf '# System Health %s\n\n' "${day}"
      printf -- '- GPU health: [[System/GPU Health/index]]\n'
      printf -- '- Codex conversations: [[codex-conversations/index]]\n'
      printf -- '- Structured log: `%s`\n\n' "${log_file}"
      printf '## Events\n\n'
    } > "${note_file}"
  fi

  {
    printf '### %s\n\n' "${ts}"
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Reason: %s\n' "${reason}"
    printf -- '- Kernel: `%s`\n' "${boot_kernel}"
    printf -- '- Disk usage: `/boot %s%%`, `/ %s%%`, `/home %s%%`\n' "${boot_use}" "${root_use}" "${home_use}"
    if [[ -n "${journal_disk}" ]]; then
      printf -- '- Journal usage: `%s`\n' "${journal_disk}"
    fi
    append_block_if_present "${failed_system}"
    append_block_if_present "${failed_user}"
    append_block_if_present "${unclean_shutdown_markers}"
    append_block_if_present "${current_desktop_incidents}"
    append_block_if_present "${previous_desktop_incidents}"
    append_block_if_present "${btrfs_scrub}"
    printf '\nBack: [[System/System Health/index|System Health Index]]\n\n'
  } >> "${note_file}"

  {
    printf '# System Health Index\n\n'
    printf -- '- Updated: `%s`\n\n' "$(date --iso-8601=seconds)"
    find "${obsidian_dir}" -maxdepth 1 -type f -name '20*.md' -printf '%f\n' | sort -r | while read -r file; do
      day_name="${file%.md}"
      printf -- '- [[System/System Health/%s|%s]]\n' "${day_name}" "${day_name}"
    done
  } > "${obsidian_index}"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send "System watchdog: ${status}" "${reason}" >/dev/null 2>&1 || true
  fi
fi

cat > "${state_file}" <<EOF
prev_status='${status}'
prev_reason='${reason}'
EOF

trim_file "${log_file}" 2000
