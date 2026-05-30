/**
 * AgentLight OpenClaw adapter — handler.ts
 *
 * Maps OpenClaw internal events to AgentLight states and POSTs them to the
 * local AgentLight hub (http://localhost:9527). No external CLI required.
 *
 * Status: experimental. The hub + Claude Code adapter are the verified v1;
 * this OpenClaw mapping is being finished — see docs/DESIGN.md.
 */

interface HookEvent {
  type: string;
  action: string;
  sessionKey?: string;
  timestamp: number;
  context?: {
    sessionKey?: string;
    success?: boolean;
  };
}

// OpenClaw event -> canonical AgentLight state (idle|working|confirm|error|offline)
const STATE_MAP: Record<string, string> = {
  "message:received": "working",
  "message:sent":     "idle",
  "command:new":      "working",
  "command:reset":    "idle",
  "command:stop":     "idle",
  "gateway:startup":  "idle",
  "gateway:shutdown": "offline",
};

// Hub endpoint — override with AGENTLIGHT_HUB if the hub runs elsewhere.
const HUB = process.env.AGENTLIGHT_HUB ?? "http://localhost:9527/state";

async function postState(state: string, session: string): Promise<void> {
  try {
    await fetch(HUB, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ state, source: "openclaw", session }),
      signal: AbortSignal.timeout(2000),
    });
  } catch (err) {
    // Non-fatal — hub not running.
    console.warn(`[agentlight] POST ${state} failed: ${err}`);
  }
}

const handler = async (event: HookEvent): Promise<void> => {
  const eventKey = event.action ? `${event.type}:${event.action}` : event.type;
  const state = STATE_MAP[eventKey];
  if (!state) return;

  const session = (event.context?.sessionKey ?? event.sessionKey ?? "unknown")
    .replace(/[^a-zA-Z0-9_-]/g, "_")
    .slice(0, 64);

  console.log(`[agentlight] ${eventKey} -> ${state}`);
  await postState(state, session);
};

export default handler;
