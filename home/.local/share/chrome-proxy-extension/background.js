const DEFAULT_STATE = {
  enabled: true,
  scheme: "http",
  host: "178.236.253.46",
  port: 18080,
  username: "tgshare",
  password: "KAYFObhGD84TcV9Ir52E",
  bypassDomains: [
    "localhost",
    "*.local",
    "*.home.arpa",
    "*.lan",
    "*.localhost",
    "*.ru",
    "*.su",
    "*.xn--p1ai",
    "*.vk.com"
  ],
  probeSites: [
    { id: "chatgpt", label: "ChatGPT", url: "https://chatgpt.com", expect: [200, 301, 302, 303, 307, 308, 403] },
    { id: "youtube", label: "YouTube", url: "https://www.youtube.com", expect: [200, 301, 302, 303, 307, 308] },
    { id: "github", label: "GitHub", url: "https://github.com", expect: [200, 301, 302, 303, 307, 308] },
    { id: "google", label: "Google", url: "https://www.google.com", expect: [200, 301, 302, 303, 307, 308] },
    { id: "reddit", label: "Reddit", url: "https://www.reddit.com", expect: [200, 301, 302, 303, 307, 308, 403] },
    { id: "x", label: "X", url: "https://x.com", expect: [200, 301, 302, 303, 307, 308] }
  ],
  probeResults: [],
  probeSummary: null
};

function normalizeState(state) {
  const merged = {
    ...DEFAULT_STATE,
    ...state
  };

  if (
    merged.scheme === "socks5" &&
    merged.host === "178.236.253.46" &&
    Number(merged.port) === 1088
  ) {
    merged.scheme = DEFAULT_STATE.scheme;
    merged.port = DEFAULT_STATE.port;
  }

  if (
    merged.host === DEFAULT_STATE.host &&
    Number(merged.port) === DEFAULT_STATE.port &&
    (!merged.username || !merged.password)
  ) {
    merged.username = DEFAULT_STATE.username;
    merged.password = DEFAULT_STATE.password;
  }

  if (!Array.isArray(merged.bypassDomains) || merged.bypassDomains.length === 0) {
    merged.bypassDomains = DEFAULT_STATE.bypassDomains.slice();
  }

  if (!Array.isArray(merged.probeSites) || merged.probeSites.length === 0) {
    merged.probeSites = DEFAULT_STATE.probeSites.map((site) => ({ ...site }));
  }

  return merged;
}

async function getState() {
  const stored = await chrome.storage.local.get(null);
  return normalizeState(stored);
}

function getProxyPacLabel(scheme) {
  switch (scheme) {
    case "socks4":
      return "SOCKS";
    case "socks5":
      return "SOCKS5";
    case "https":
      return "HTTPS";
    case "http":
    default:
      return "PROXY";
  }
}

function buildPacScript(state) {
  const patterns = state.bypassDomains
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);
  const proxyLabel = getProxyPacLabel(state.scheme);
  const proxyTarget = `${proxyLabel} ${state.host}:${Number(state.port)}`;

  return `
function FindProxyForURL(url, host) {
  host = (host || "").toLowerCase();
  var directPatterns = ${JSON.stringify(patterns)};

  if (!host || isPlainHostName(host) || shExpMatch(host, "localhost") || shExpMatch(host, "*.localhost")) {
    return "DIRECT";
  }

  if (/^\\d+\\.\\d+\\.\\d+\\.\\d+$/.test(host)) {
    if (
      isInNet(host, "127.0.0.0", "255.0.0.0") ||
      isInNet(host, "10.0.0.0", "255.0.0.0") ||
      isInNet(host, "172.16.0.0", "255.240.0.0") ||
      isInNet(host, "192.168.0.0", "255.255.0.0") ||
      isInNet(host, "100.64.0.0", "255.192.0.0") ||
      isInNet(host, "169.254.0.0", "255.255.0.0")
    ) {
      return "DIRECT";
    }
  } else {
    var resolved = dnsResolve(host);
    if (resolved) {
      if (
        isInNet(resolved, "127.0.0.0", "255.0.0.0") ||
        isInNet(resolved, "10.0.0.0", "255.0.0.0") ||
        isInNet(resolved, "172.16.0.0", "255.240.0.0") ||
        isInNet(resolved, "192.168.0.0", "255.255.0.0") ||
        isInNet(resolved, "100.64.0.0", "255.192.0.0") ||
        isInNet(resolved, "169.254.0.0", "255.255.0.0")
      ) {
        return "DIRECT";
      }
    }
  }

  for (var i = 0; i < directPatterns.length; i += 1) {
    var pattern = directPatterns[i];
    if (shExpMatch(host, pattern)) {
      return "DIRECT";
    }

    if (pattern.startsWith("*.")) {
      var suffix = pattern.slice(1);
      if (dnsDomainIs(host, suffix) || host === suffix.slice(1)) {
        return "DIRECT";
      }
    }
  }

  return "${proxyTarget}; DIRECT";
}
  `.trim();
}

async function setBadge(enabled) {
  await chrome.action.setBadgeBackgroundColor({
    color: enabled ? "#1f8b4c" : "#6b7280"
  });
  await chrome.action.setBadgeText({
    text: enabled ? "ON" : "OFF"
  });
}

async function applyProxyConfig() {
  const state = await getState();

  if (!state.enabled) {
    await chrome.proxy.settings.set({
      value: { mode: "system" },
      scope: "regular"
    });
    await setBadge(false);
    return state;
  }

  await chrome.proxy.settings.set({
    value: {
      mode: "pac_script",
      pacScript: {
        data: buildPacScript(state)
      }
    },
    scope: "regular"
  });

  await setBadge(true);
  return state;
}

async function toggleEnabled() {
  const state = await getState();
  await chrome.storage.local.set({ enabled: !state.enabled });
  return applyProxyConfig();
}

function probeWithTimeout(url, options = {}, timeoutMs = 8000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("timeout")), timeoutMs);
    fetch(url, options)
      .then((response) => {
        clearTimeout(timer);
        resolve(response);
      })
      .catch((error) => {
        clearTimeout(timer);
        reject(error);
      });
  });
}

async function runSiteProbe(site) {
  const startedAt = Date.now();

  try {
    const response = await probeWithTimeout(site.url, {
      method: "GET",
      redirect: "follow",
      cache: "no-store"
    });
    const durationMs = Date.now() - startedAt;
    const expected = Array.isArray(site.expect) ? site.expect : [];
    const ok = expected.length === 0 ? response.ok : expected.includes(response.status);

    return {
      id: site.id,
      label: site.label,
      url: site.url,
      ok,
      status: response.status,
      durationMs,
      checkedAt: new Date().toISOString()
    };
  } catch (error) {
    return {
      id: site.id,
      label: site.label,
      url: site.url,
      ok: false,
      error: String(error?.message || error),
      checkedAt: new Date().toISOString()
    };
  }
}

async function runAllProbes() {
  const state = await getState();
  const results = await Promise.all(state.probeSites.map((site) => runSiteProbe(site)));
  const payload = {
    probeResults: results,
    probeSummary: {
      total: results.length,
      ok: results.filter((result) => result.ok).length,
      checkedAt: new Date().toISOString()
    }
  };
  await chrome.storage.local.set(payload);
  return payload;
}

chrome.runtime.onInstalled.addListener(async () => {
  const state = await getState();
  await chrome.storage.local.set(state);
  await applyProxyConfig();
  await runAllProbes();
});

chrome.runtime.onStartup.addListener(() => {
  void applyProxyConfig();
  void runAllProbes();
});

chrome.storage.onChanged.addListener((changes, areaName) => {
  if (areaName !== "local" || Object.keys(changes).length === 0) {
    return;
  }
  void applyProxyConfig();
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "get-state") {
    void getState().then((state) => sendResponse(state));
    return true;
  }

  if (message?.type === "save-state") {
    void chrome.storage.local.set(message.payload).then(async () => {
      const state = await applyProxyConfig();
      sendResponse(state);
    });
    return true;
  }

  if (message?.type === "toggle-enabled") {
    void toggleEnabled().then((state) => sendResponse(state));
    return true;
  }

  if (message?.type === "run-probes") {
    void runAllProbes().then((result) => sendResponse(result));
    return true;
  }

  return false;
});

chrome.proxy.onProxyError.addListener((details) => {
  console.warn("chrome-proxy-extension error", details);
});

chrome.webRequest.onAuthRequired.addListener(
  async (details, callback) => {
    const state = await getState();

    if (
      !details.isProxy ||
      !state.username ||
      details.challenger?.host !== state.host ||
      Number(details.challenger?.port) !== Number(state.port)
    ) {
      callback();
      return;
    }

    callback({
      authCredentials: {
        username: state.username,
        password: state.password
      }
    });
  },
  { urls: ["<all_urls>"] },
  ["asyncBlocking"]
);
