const API_BASE = "http://127.0.0.1:8000";

export async function sendChat(messages) {
  const response = await fetch(`${API_BASE}/api/chat`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({messages}),
  });

  let data = {};
  try { data = await response.json(); } catch {}

  if (!response.ok) {
    throw new Error(data.detail || "Unable to contact PocketSmart AI.");
  }
  return data.message;
}

export async function checkHealth() {
  const response = await fetch(`${API_BASE}/health`);
  if (!response.ok) throw new Error("Backend unavailable");
  return response.json();
}
