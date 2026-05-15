const statusEl = document.getElementById("status");
const schemeEl = document.getElementById("scheme");
const hostEl = document.getElementById("host");
const portEl = document.getElementById("port");
const usernameEl = document.getElementById("username");
const passwordEl = document.getElementById("password");
const bypassDomainsEl = document.getElementById("bypassDomains");
const saveEl = document.getElementById("save");
const probeEl = document.getElementById("probe");
const probeMetaEl = document.getElementById("probeMeta");
const probeListEl = document.getElementById("probeList");
const toggleEl = document.getElementById("toggle");
const summaryEndpointEl = document.getElementById("summaryEndpoint");
const summaryAuthEl = document.getElementById("summaryAuth");
const summaryChecksEl = document.getElementById("summaryChecks");

let currentState = null;

function formatTimestamp(value) {
  if (!value) {
    return "never";
  }

  const date = new Date(value);
  return date.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit"
  });
}

function renderProbeResults(results = [], summary = null) {
  probeListEl.textContent = "";

  if (!results.length) {
    probeMetaEl.textContent = "No checks yet.";
    summaryChecksEl.textContent = "0/0";
    return;
  }

  results.forEach((result) => {
    const card = document.createElement("article");
    card.className = `probe-card ${result.ok ? "ok" : "bad"}`;

    const name = document.createElement("p");
    name.className = "probe-name";
    name.textContent = result.label;

    const url = document.createElement("p");
    url.className = "probe-url";
    url.textContent = result.url;

    const badge = document.createElement("span");
    badge.className = "probe-badge";
    badge.textContent = result.ok
      ? `${result.status} OK`
      : result.status
        ? `${result.status} issue`
        : "No route";

    const detail = document.createElement("p");
    detail.className = "probe-detail";
    detail.textContent = result.ok
      ? `Checked ${formatTimestamp(result.checkedAt)} in ${result.durationMs} ms`
      : `Checked ${formatTimestamp(result.checkedAt)}: ${result.error || `unexpected status ${result.status}`}`;

    const textWrap = document.createElement("div");
    textWrap.append(name, url);
    card.append(textWrap, badge, detail);
    probeListEl.append(card);
  });

  if (summary) {
    probeMetaEl.textContent = `Last run ${formatTimestamp(summary.checkedAt)}. ${summary.ok}/${summary.total} sites reachable through proxy.`;
    summaryChecksEl.textContent = `${summary.ok}/${summary.total}`;
  }
}

function render(state) {
  currentState = state;
  const endpoint = `${state.scheme}://${state.host}:${state.port}`;
  statusEl.textContent = state.enabled
    ? `Enabled via ${endpoint}`
    : "Disabled and following system proxy settings";
  schemeEl.value = state.scheme;
  hostEl.value = state.host;
  portEl.value = state.port;
  usernameEl.value = state.username || "";
  passwordEl.value = state.password || "";
  bypassDomainsEl.value = state.bypassDomains.join("\n");
  summaryEndpointEl.textContent = `${state.host}:${state.port}`;
  summaryAuthEl.textContent = state.username ? `user ${state.username}` : "none";
  toggleEl.textContent = state.enabled ? "Disable" : "Enable";
  renderProbeResults(state.probeResults, state.probeSummary);
}

async function refresh() {
  const state = await chrome.runtime.sendMessage({ type: "get-state" });
  render(state);
}

saveEl.addEventListener("click", async () => {
  saveEl.disabled = true;
  const state = await chrome.runtime.sendMessage({
    type: "save-state",
    payload: {
      scheme: schemeEl.value,
      host: hostEl.value.trim(),
      port: Number(portEl.value),
      username: usernameEl.value.trim(),
      password: passwordEl.value,
      bypassDomains: bypassDomainsEl.value
        .split("\n")
        .map((value) => value.trim())
        .filter(Boolean)
    }
  });
  render(state);
  saveEl.disabled = false;
});

probeEl.addEventListener("click", async () => {
  probeEl.disabled = true;
  probeMetaEl.textContent = "Running checks...";
  const result = await chrome.runtime.sendMessage({ type: "run-probes" });
  render({
    ...currentState,
    probeResults: result.probeResults,
    probeSummary: result.probeSummary
  });
  probeEl.disabled = false;
});

toggleEl.addEventListener("click", async () => {
  toggleEl.disabled = true;
  const state = await chrome.runtime.sendMessage({ type: "toggle-enabled" });
  render(state);
  toggleEl.disabled = false;
});

void refresh().then(() => {
  if (!currentState?.probeSummary?.checkedAt) {
    probeEl.click();
  }
});
