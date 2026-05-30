/**
 * AgentLight OpenClaw adapter — handler.ts
 *
 * Maps OpenClaw internal events to AgentLight states and POSTs them to the
 * local AgentLight hub (http://localhost:9527). No external CLI required.
 *
 * Verified against OpenClaw 2026.5.12: the hook is discovered/enabled by the
 * `openclaw hooks` system and the handler POSTs the mapped states to the hub.
 * See docs/DESIGN.md.
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

// OpenClaw event ("<type>:<action>") -> canonical AgentLight state.
// Event types/actions verified against OpenClaw 2026.5.12's internal hook API.
// Note: there is no "gateway:shutdown" event, so offline is not emitted here.
const STATE_MAP: Record<string, string> = {
  "message:received": "working",  // user message arrived → agent starts working
  "message:sent":     "idle",     // agent replied → done
  "command:new":      "idle",     // /new clears the session
  "command:reset":    "idle",     // /reset
  "command:stop":     "idle",     // /stop halts generation
  "gateway:startup":  "idle",     // gateway ready
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
