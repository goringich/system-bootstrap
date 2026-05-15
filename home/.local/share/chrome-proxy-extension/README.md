# Chrome Proxy Profile Extension

This unpacked Chrome extension is loaded only by the dedicated `chrome-proxy`
launcher/profile.

- Default proxy endpoint: `socks5://178.236.253.46:1088`
- Auth: optional username/password handled by the extension
- Routing note: browser-only direct rules are configured in the popup

The launcher at `~/.local/bin/chrome-proxy` loads this extension explicitly with
`--load-extension`, so it does not affect the normal Chrome profile.
