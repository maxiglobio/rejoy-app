// Supabase Edge Function: send APNs when someone reacts (smile) to a session in Karma Partners.
// Trigger via Database Webhook on session_reactions INSERT.
//
// Required secrets (same as nudge-push):
//   APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_P8, APNS_BUNDLE_ID, APNS_PRODUCTION
// Run migration 018_push_token.sql so profiles.push_token exists.

import { createClient } from "npm:@supabase/supabase-js@2";
import * as jose from "npm:jose@5.9.6";

interface ReactionRecord {
  session_id: string;
  reactor_user_id: string;
  created_at: string;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: ReactionRecord;
  schema: string;
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

async function createApnsToken(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const keyP8 = Deno.env.get("APNS_KEY_P8");
  if (!keyId || !teamId || !keyP8) {
    throw new Error("Missing APNS_KEY_ID, APNS_TEAM_ID, or APNS_KEY_P8");
  }
  const key = await jose.importPKCS8(keyP8, "ES256");
  return await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(key);
}

async function sendApnsPush(
  deviceToken: string,
  title: string,
  body: string,
  bundleId: string
): Promise<Response> {
  const jwt = await createApnsToken();
  const isProduction = Deno.env.get("APNS_PRODUCTION") === "true";
  const host = isProduction
    ? "api.push.apple.com"
    : "api.sandbox.push.apple.com";
  const url = `https://${host}/3/device/${deviceToken}`;

  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
    },
  };

  return fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-topic": bundleId,
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    if (payload.type !== "INSERT" || payload.table !== "session_reactions") {
      return new Response(
        JSON.stringify({ ok: true, skipped: "not a reaction insert" }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const reaction = payload.record;
    const sessionId = reaction.session_id;
    const reactorId = reaction.reactor_user_id;

    const { data: session } = await supabase
      .from("sessions")
      .select("user_id")
      .eq("id", sessionId)
      .single();

    const ownerId = session?.user_id as string | undefined;
    if (!ownerId) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "session not found" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const ownerLower = ownerId.toLowerCase();
    const reactorLower = reactorId.toLowerCase();
    if (ownerLower === reactorLower) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "self-reaction" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const { data: ownerProfile, error: ownerErr } = await supabase
      .from("profiles")
      .select("push_token")
      .eq("id", ownerId)
      .single();

    if (ownerErr || !ownerProfile?.push_token) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "no push_token for session owner" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const { data: reactorProfile } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", reactorId)
      .single();

    const reactorName =
      reactorProfile?.display_name?.trim() || "Someone";
    const title = `${reactorName} smiled at your practice!`;
    const body = "See it in Karma Partners.";

    const bundleId = Deno.env.get("APNS_BUNDLE_ID");
    if (!bundleId) {
      throw new Error("Missing APNS_BUNDLE_ID");
    }

    const res = await sendApnsPush(
      ownerProfile.push_token,
      title,
      body,
      bundleId
    );

    if (!res.ok) {
      const text = await res.text();
      console.error("APNs error:", res.status, text);
      return new Response(
        JSON.stringify({ ok: false, error: text }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ ok: true, apnsId: res.headers.get("apns-id") }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("reaction-push error:", e);
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
