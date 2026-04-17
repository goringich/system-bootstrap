#!/usr/bin/env bash
set -euo pipefail

arch_target='/etc/pacman.d/mirrorlist'
cachyos_target='/etc/pacman.d/cachyos-mirrorlist'
state_dir='/var/lib/pacman-network-mirror-mode'
state_file="${state_dir}/state"
override_file='/etc/pacman.d/network-mirror-mode.override'

arch_global='
Server = https://fastly.mirror.pkgbuild.com/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = https://mirror.telepoint.bg/archlinux/$repo/os/$arch
Server = https://archlinux.mirror-services.net/archlinux/$repo/os/$arch
'

arch_ru='
Server = https://repository.su/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://fastly.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.telepoint.bg/archlinux/$repo/os/$arch
'

cachyos_global='
Server = https://at.cachyos.org/repo/$arch/$repo
Server = https://us.cachyos.org/repo/$arch/$repo
Server = https://mirror.mergedcloud.de/cachyos/repo/$arch/$repo
Server = https://no.mirror.cx/cachyos/repo/$arch/$repo
Server = https://nl.mirror.cx/cachyos/repo/$arch/$repo
'

cachyos_ru='
Server = https://mirror.jura12.ru/repo/$arch/$repo
Server = https://wan.metrosg.ru/cachyos/repo/$arch/$repo
Server = https://mirror.cachy-arch.ru/cachyos/repo/$arch/$repo
Server = https://at.cachyos.org/repo/$arch/$repo
Server = https://us.cachyos.org/repo/$arch/$repo
'

vpn_active() {
    if ip route show default 2>/dev/null | grep -Eiq 'tun|wg|tailscale|warp|ppp|tap|cachyOs'; then
        return 0
    fi

    if pgrep -af 'hiddify|HiddifyCli|sing-box|xray|clash|mihomo|warp-svc|openvpn|wireguard-go' >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

selected_mode() {
    if [[ -f "${override_file}" ]]; then
        local override
        override="$(tr -d '[:space:]' < "${override_file}")"
        if [[ "${override}" == 'global' || "${override}" == 'ru' ]]; then
            printf '%s\n' "${override}"
            return 0
        fi
    fi

    if vpn_active; then
        printf 'global\n'
    else
        printf 'ru\n'
    fi
}

write_list() {
    local mode="$1"
    local target="$2"
    local payload="$3"
    local tmp
    tmp="$(mktemp)"
    {
        printf '# managed by pacman-network-mirror-mode\n'
        printf '# mode: %s\n' "${mode}"
        printf '%s' "${payload}"
    } > "${tmp}"
    install -Dm644 "${tmp}" "${target}"
    rm -f "${tmp}"
}

main() {
    mkdir -p "${state_dir}"

    local mode
    mode="$(selected_mode)"

    if [[ -f "${state_file}" ]] && [[ "$(cat "${state_file}")" == "${mode}" ]]; then
        exit 0
    fi

    if [[ "${mode}" == 'global' ]]; then
        write_list "${mode}" "${arch_target}" "${arch_global}"
        write_list "${mode}" "${cachyos_target}" "${cachyos_global}"
    else
        write_list "${mode}" "${arch_target}" "${arch_ru}"
        write_list "${mode}" "${cachyos_target}" "${cachyos_ru}"
    fi

    printf '%s\n' "${mode}" > "${state_file}"
    printf 'Mirror mode set to %s\n' "${mode}"
}

main "$@"
