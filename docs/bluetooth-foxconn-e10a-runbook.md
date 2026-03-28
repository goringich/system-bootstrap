# Bluetooth Foxconn `0489:e10a` Runbook

## Scope

This machine has an onboard Foxconn / Hon Hai Bluetooth adapter with USB ID `0489:e10a`.
BlueZ identifies it as a Qualcomm controller.

## Why It Did Not Work Immediately

The failure was not a single GUI issue.
It was a stack:

1. `btusb` was loaded with `enable_autosuspend=Y`
2. the onboard USB function `1-12` repeatedly drifted into `power/control=auto`
3. the adapter therefore dropped into `runtime_status=suspended`
4. Waybar and `blueman` then looked empty or inconsistent because BlueZ was scanning with a half-dead adapter
5. this Foxconn/QCA family is already known to be unstable on Linux on several MSI AMD boards

## Confirmed Symptoms

- `bluetoothctl show` reported `Powered: yes` and sometimes `Discovering: yes`
- `bluetoothctl devices` often stayed empty
- live interactive scan only intermittently emitted `NEW Device` lines
- the adapter could re-enter suspended state even after a manual wake
- AirPods Pro could be discovered and paired, but connection could still fail with:
  - `org.bluez.Error.InProgress br-connection-busy`
  - `org.bluez.Error.Failed le-connection-abort-by-local`

## Applied Machine Fixes

### Driver-level

- `/etc/modprobe.d/btusb-local.conf`
- forced `options btusb enable_autosuspend=n reset=Y`

### USB wake enforcement

- `/etc/udev/rules.d/99-bluetooth-no-autosuspend.rules`
- `/etc/systemd/system/bluetooth-usb-awake.service`

Target state:

- `power/control=on`
- `runtime_status=active`

### Self-healing

- `/etc/systemd/system/bluetooth-self-heal.service`
- `/etc/systemd/system/bluetooth-self-heal.timer`
- `/etc/systemd/system/bluetooth.service.d/restart.conf`
- `~/__home_organized/scripts/bluetooth-self-heal.sh`

This adds periodic recovery plus restart-on-failure for `bluetooth.service`.

## GUI Integration Changes

### Bluetooth UI

- `~/.config/hypr/scripts/BluetoothMenu.sh`
- `~/.config/waybar/Modules`

Waybar no longer depends only on BlueZ cached devices.
The menu also parses fresh `NEW Device` scan output so devices can appear even when `bluetoothctl devices` remains empty.

### Audio output UI

- `~/.config/hypr/scripts/AudioOutputMenu.sh`
- `~/.config/waybar/Modules`

This gives a reliable Rofi output-device selector for PipeWire sinks.

## Reproducible Bring-up

The required system-level files are now captured in:

- `configs/system-paths.txt`
- `system/`

`install.sh` and `capture-state.sh` were extended so these `/etc` overlays can be restored together with the home snapshot.

## Verification

Expected:

```bash
cat /sys/module/btusb/parameters/enable_autosuspend
cat /sys/bus/usb/devices/1-12/power/control
cat /sys/bus/usb/devices/1-12/power/runtime_status
systemctl status bluetooth.service bluetooth-self-heal.timer --no-pager
```

Target values:

- `enable_autosuspend = N`
- `power/control = on`
- `runtime_status = active`

Discovery test:

```bash
bluetoothctl
scan on
```

Success condition:

- interactive scan emits `NEW Device ...`

## Residual Risk

This fix makes the onboard adapter materially more usable, but it does not turn `0489:e10a` into perfectly reliable hardware.
If long-term Bluetooth stability remains unacceptable, the clean fallback is an external USB Bluetooth dongle with a better-supported chipset.
