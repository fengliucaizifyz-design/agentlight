/**
 * AgentLight OpenClaw Hook — handler.ts
 *
 * Maps OpenClaw internal events to AgentLight state changes.
 * Runs in demo mode (--demo) writing to a JSON file instead of USB.
 */

import { execSync } from "child_process";
import { resolve } from "path";

interface HookEvent {
  type: string;
  action: string;
  sessionKey?: string;
  timestamp: number;
  context?: {
    sessionKey?: string;
    from?: string;
    to?: string;
    content?: string;
    success?: boolean;
  };
}

const STATE_MAP: Record<string, string> = {
  "message:received": "thinking",
  "message:sent":     "success",
  "command:new":      "thinking",
  "command:reset":    "idle",
  "command:stop":     "idle",
  "gateway:startup":  "idle",
  "gateway:shutdown": "idle",
};

// Build the agentlight CLI command safely
function agentlightSet(state: string, sessionKey: string, demoFile: string): void {
  const args = [
    "set", state,
    "--source", "openclaw",
    "--session", sessionKey,
    "--demo",
    "--demo-file", demoFile,
  ];

  try {
    execSync(`agentlight ${args.join(" ")}`, {
      timeout: 5000,
      stdio: "ignore",
    });
  } catch (err) {
    // Non-fatal — agentlight not installed or demo file not writable
    console.warn(`[agentlight hook] agentlight set ${state} failed: ${err}`);
  }
}

const handler = async (event: HookEvent): Promise<void> => {
  const eventKey = event.action
    ? `${event.type}:${event.action}`
    : event.type;

  const state = STATE_MAP[eventKey];
  if (!state) return;

  console.log(`[agentlight hook] firing: ${eventKey} -> ${state}`);

  // Derive a session identifier
  const sessionKey = (event.context?.sessionKey ?? event.sessionKey ?? "unknown")
    .replace(/[^a-zA-Z0-9_-]/g, "_")
    .slice(0, 64);

  // Demo file: absolute path to avoid cwd issues when gateway runs hooks
  const demoFile = process.env.AGENTLIGHT_DEMO_FILE ??
    "/Users/tifosi/.openclaw/workspace/examples/agentlight-state.json";

  agentlightSet(state, sessionKey, demoFile);
};

export default handler;