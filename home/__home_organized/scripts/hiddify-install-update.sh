#!/usr/bin/env bash
set -euo pipefail

repo_api='https://api.github.com/repos/hiddify/hiddify-app/releases/latest'
asset_name='Hiddify-Linux-x64-AppImage.AppImage'

base_dir="${HOME}/__home_organized/artifacts/hiddify"
releases_dir="${base_dir}/releases"
current_link="${base_dir}/current"
tmp_dir="$(mktemp -d)"
cleanup() {
    rm -rf "${tmp_dir}"
}
trap cleanup EXIT

mkdir -p "${releases_dir}"

release_json="${tmp_dir}/release.json"
curl -fsSL "${repo_api}" -o "${release_json}"

tag="$(jq -r '.tag_name' "${release_json}")"
download_url="$(jq -r --arg asset "${asset_name}" '.assets[] | select(.name == $asset) | .browser_download_url' "${release_json}")"

if [[ -z "${tag}" || "${tag}" == "null" || -z "${download_url}" || "${download_url}" == "null" ]]; then
    printf 'Failed to resolve the latest Hiddify Linux release.\n' >&2
    exit 1
fi

version_dir="${releases_dir}/${tag}"
appimage_path="${version_dir}/${asset_name}"
extract_dir="${version_dir}/squashfs-root"

mkdir -p "${version_dir}"

if [[ ! -f "${appimage_path}" ]]; then
    curl -fL "${download_url}" -o "${appimage_path}"
fi

chmod +x "${appimage_path}"

if [[ ! -d "${extract_dir}" ]]; then
    (
        cd "${version_dir}"
        rm -rf squashfs-root
        "${appimage_path}" --appimage-extract >/dev/null
    )
fi

ln -sfn "${extract_dir}" "${current_link}"

printf 'Installed Hiddify %s\n' "${tag}"
printf 'AppImage: %s\n' "${appimage_path}"
printf 'Runtime:  %s\n' "${extract_dir}"
