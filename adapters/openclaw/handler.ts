/**
 * AgentLight OpenClaw adapter — handler.ts
 *
 * Maps OpenClaw internal events to AgentLight states and POSTs them to the
 * local AgentLight hub (http://127.0.0.1:9527). No external CLI required.
 *
 * Verified against OpenClaw 2026.5.12: the hook is discovered/enabled by the
 * `openclaw hooks` system and the handler POSTs the mapped states to the hub.
 * See docs/DESIGN.md.
 */

import http from "node:http";

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
const STATE_MAP: Record<string, string> = {
  "message:received": "working",  // user message arrived → agent starts working
  "command:new":      "idle",     // /new clears the session
  "command:reset":    "idle",     // /reset
  "command:stop":     "idle",     // /stop halts generation
  "gateway:startup":    "idle",    // gateway ready
  "gateway:shutdown":   "offline", // gateway stopping
  "gateway:pre-restart": "offline", // gateway about to restart
};

// Hub endpoint. Use 127.0.0.1 by default and node:http below so local posts are
// not captured by HTTP_PROXY / undici global proxy dispatchers.
const HUB = process.env.AGENTLIGHT_HUB ?? "http://127.0.0.1:9527/state";

function resolveState(eventKey: string, event: HookEvent): string | undefined {
  if (eventKey === "message:sent") {
    return event.context?.success === false ? "error" : "idle";
  }
  return STATE_MAP[eventKey];
}

async function postState(state: string, session: string): Promise<void> {
  const url = new URL(HUB);
  if (url.protocol !== "http:") {
    console.warn(`[agentlight] unsupported hub protocol: ${url.protocol}`);
    return;
  }

  const body = JSON.stringify({ state, source: "openclaw", session });

  await new Promise<void>((resolve) => {
    const req = http.request({
      hostname: url.hostname,
      port: url.port || "80",
      path: `${url.pathname}${url.search}`,
      method: "POST",
      timeout: 2000,
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    }, (res) => {
      res.resume();
      res.on("end", resolve);
    });

    req.on("timeout", () => req.destroy(new Error("request timed out")));
    req.on("error", (err) => {
      // Non-fatal — hub not running.
      console.warn(`[agentlight] POST ${state} failed: ${err}`);
      resolve();
    });
    req.end(body);
  });
}

const handler = async (event: HookEvent): Promise<void> => {
  const eventKey = event.action ? `${event.type}:${event.action}` : event.type;
  const state = resolveState(eventKey, event);
  if (!state) return;

  const session = (event.context?.sessionKey ?? event.sessionKey ?? "unknown")
    .replace(/[^a-zA-Z0-9_-]/g, "_")
    .slice(0, 64);

  console.log(`[agentlight] ${eventKey} -> ${state}`);
  await postState(state, session);
};

export default handler;
