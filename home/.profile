export BROWSER=firefox
export TERM=alacritty
export QT_QPA_PLATFORMTHEME="qt5ct"
export GTK_THEME=adw-gtk3-dark

# force sane makepkg settings for AUR builds
export MAKEPKG_CONF="$HOME/.makepkg.conf"


# flatpak desktop entries
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"


# user binaries
export PATH="$HOME/.local/bin:$PATH"

