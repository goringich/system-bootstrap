#!/usr/bin/env bash
set -euo pipefail

USB_DEVICE="1-12"
USB_PATH="/sys/bus/usb/devices/${USB_DEVICE}"
POWER_CONTROL="${USB_PATH}/power/control"
RUNTIME_STATUS="${USB_PATH}/power/runtime_status"

ensure_awake() {
  [[ -w "${POWER_CONTROL}" ]] || return 0
  local current
  current="$(<"${POWER_CONTROL}")"
  if [[ "${current}" != "on" ]]; then
    printf 'on' > "${POWER_CONTROL}"
  fi
}

controller_present() {
  busctl --system get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered >/dev/null 2>&1
}

controller_powered() {
  local state
  state="$(busctl --system get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered 2>/dev/null | awk '{print $2}')"
  [[ "${state}" == "true" ]]
}

usb_rebind() {
  [[ -w /sys/bus/usb/drivers/usb/unbind ]] || return 1
  [[ -w /sys/bus/usb/drivers/usb/bind ]] || return 1
  printf '%s' "${USB_DEVICE}" > /sys/bus/usb/drivers/usb/unbind
  sleep 2
  printf '%s' "${USB_DEVICE}" > /sys/bus/usb/drivers/usb/bind
}

main() {
  ensure_awake

  if controller_present && controller_powered; then
    exit 0
  fi

  usb_rebind || true
  ensure_awake
  systemctl restart bluetooth.service
}

main "$@"
