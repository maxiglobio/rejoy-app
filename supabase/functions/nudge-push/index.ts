// Supabase Edge Function: send APNs push when a nudge is inserted.
// Trigger via Database Webhook on activity_nudges INSERT.
//
// Required secrets:
//   APNS_KEY_ID      - Key ID from Apple Developer
//   APNS_TEAM_ID     - Team ID from Apple Developer
//   APNS_KEY_P8      - Contents of .p8 auth key file
//   APNS_BUNDLE_ID   - App bundle ID (e.g. com.rejoy.app)
//   APNS_PRODUCTION  - "true" for production, "false" for sandbox
//
// Run migration 018_push_token.sql first to add push_token to profiles.

import { createClient } from "npm:@supabase/supabase-js@2";
import * as jose from "npm:jose@5.9.6";

interface NudgeRecord {
  id: string;
  sender_user_id: string;
  receiver_user_id: string;
  created_at: string;
  seen_at: string | null;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: NudgeRecord;
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
    if (payload.type !== "INSERT" || payload.table !== "activity_nudges") {
      return new Response(JSON.stringify({ ok: true, skipped: "not a nudge insert" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const nudge = payload.record;
    const receiverId = nudge.receiver_user_id;

    const { data: profile, error } = await supabase
      .from("profiles")
      .select("push_token")
      .eq("id", receiverId)
      .single();

    if (error || !profile?.push_token) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "no push_token for receiver" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", nudge.sender_user_id)
      .single();

    const senderName =
      senderProfile?.display_name?.trim() || "Someone";
    const title = `${senderName} is rooting for you!`;
    const body = "Start an activity to plant seeds.";

    const bundleId = Deno.env.get("APNS_BUNDLE_ID");
    if (!bundleId) {
      throw new Error("Missing APNS_BUNDLE_ID");
    }

    const res = await sendApnsPush(
      profile.push_token,
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
    console.error("nudge-push error:", e);
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
