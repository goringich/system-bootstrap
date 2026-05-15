#!/usr/bin/env bash
set -euo pipefail

config_file="${1:-${HOME}/.config/hypr/UserConfigs/ENVariables.conf}"

[[ -f "${config_file}" ]] || {
  printf 'missing config file: %s\n' "${config_file}" >&2
  exit 1
}

rg -q '^env = AQ_NO_MODIFIERS,1$' "${config_file}" || {
  printf 'AQ_NO_MODIFIERS stability override is missing\n' >&2
  exit 1
}

if rg -q '^[[:space:]]*env = AQ_DRM_DEVICES,' "${config_file}"; then
  printf 'AQ_DRM_DEVICES is active; expected it to stay disabled for this test path\n' >&2
  exit 1
fi

if rg -q '^[[:space:]]*env = WLR_DRM_NO_ATOMIC,1$' "${config_file}"; then
  printf 'WLR_DRM_NO_ATOMIC is active; expected it to stay disabled for this test path\n' >&2
  exit 1
fi

printf 'hypr nvidia stability self-test: ok\n'
