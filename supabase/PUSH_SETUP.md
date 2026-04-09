# Push Notifications Setup (Nudges & Karma Reactions)

This guide explains how to enable real push notifications when someone sends a **nudge** or taps the **smile** on your session in Karma Partners, so users are notified even when the app is closed. Both flows use the same APNs secrets.

## 1. Run the migration

In Supabase Dashboard → SQL Editor, run:

```sql
-- From Rejoy/Supabase/migrations/018_push_token.sql
alter table public.profiles add column if not exists push_token text;
```

## 2. Apple Developer: Create APNs key

1. Go to [Apple Developer](https://developer.apple.com) → Certificates, Identifiers & Profiles → Keys
2. Create a new key (+)
3. Enable **Apple Push Notifications service (APNs)**
4. Download the `.p8` file (you can only download it once)
5. Note your **Key ID** and **Team ID**

## 3. Deploy the Edge Function

If the `supabase` CLI is not installed globally, prefix commands with `npx --yes` (for example `npx --yes supabase functions deploy …`).

```bash
cd /path/to/Rejoy
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"
supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"
supabase secrets set APNS_KEY_P8="$(cat /path/to/AuthKey_XXXXX.p8)"
supabase secrets set APNS_BUNDLE_ID="com.globio.rejoy"   # Your app bundle ID
supabase secrets set APNS_PRODUCTION="false"   # Use "true" for production/App Store
supabase functions deploy nudge-push --no-verify-jwt
supabase functions deploy reaction-push --no-verify-jwt
```

## 4. Create the Database Webhooks

### Critical: table → function mapping

Each webhook **must** invoke **only** the Edge Function that handles that table. The functions early-return if the wrong table is sent, so **no notification reaches Apple**:

| Table | Edge Function |
|-------|----------------|
| `public.activity_nudges` | `nudge-push` |
| `public.session_reactions` | `reaction-push` |

If `session_reactions` is wired to `nudge-push`, inserts are ignored (`skipped: not a nudge insert`) and pushes never fire. Double-check the **Edge Function** dropdown when editing each webhook.

### Timeout

Set **Timeout** to **5000–10000 ms** on **both** webhooks. The minimum (1000 ms) is often too short after a cold start plus the APNs round-trip.

### Nudge pushes

1. In Supabase Dashboard → Database → Webhooks
2. Create or edit webhook
3. **Table**: `public.activity_nudges`
4. **Events**: Insert
5. **Type**: Supabase Edge Function
6. **Function**: `nudge-push` (not `reaction-push`)
7. **Timeout**: 5000–10000 ms
8. **HTTP Headers**: Add auth header with service role key if your project requires it

### Karma Partners reaction (smile) pushes

When someone reacts to a finished session, the **session owner** gets a push (the reactor does not).

1. In Supabase Dashboard → Database → Webhooks
2. Create or edit webhook
3. **Table**: `public.session_reactions`
4. **Events**: Insert
5. **Type**: Supabase Edge Function
6. **Function**: `reaction-push` (not `nudge-push`)
7. **Timeout**: 5000–10000 ms
8. **HTTP Headers**: Same pattern as the nudge webhook (service role if required by your project)

The Edge Function loads `sessions.user_id` for the reacted session, skips if the reactor is the owner, and sends APNs to the owner’s `profiles.push_token`.

## 5. iOS: Push Notifications capability

The entitlements file already includes `aps-environment`. Ensure your Xcode project has the **Push Notifications** capability enabled:

1. Select the Rejoy target
2. Signing & Capabilities → + Capability → Push Notifications

For production (App Store) builds, change `aps-environment` in Rejoy.entitlements to `production` or use a build configuration.

## 6. Test

1. Build and run on a **physical device** (push does not work on simulator)
2. Sign in and grant notification permission
3. **Nudge:** Have another user send you a nudge — you should get a push in the background or when the app is closed.
4. **Reaction:** Have another user smile on one of your finished sessions in Karma Partners — you (the session owner) should get a push with the reactor’s name in the title.
5. After testing, open **Supabase → Edge Functions →** `nudge-push` **or** `reaction-push` **→ Logs** and confirm you see successful responses (not only `skipped`).

## 7. Troubleshooting (nothing in Apple Push console)

If Apple’s dashboard shows **zero** notifications, work through these in order:

1. **Webhook → function** — See the **table → function mapping** table in section 4 above.
2. **`APNS_PRODUCTION`** — Must match how the app was installed: **`false`** for Xcode/debug device builds (sandbox tokens), **`true`** for TestFlight and App Store (production tokens). A mismatch causes APNs to reject the device token.
3. **`APNS_BUNDLE_ID`** — Must match the app identifier (e.g. `com.globio.rejoy`).
4. **`profiles.push_token`** — In **Table Editor → `profiles`**, confirm the **receiver** (nudge) or **session owner** (reaction) has a non-null `push_token` after opening the app with notification permission granted.
5. **Secrets** — Confirm `APNS_KEY_ID`, `APNS_TEAM_ID`, and `APNS_KEY_P8` are set on the same Supabase project you deployed to (`supabase secrets list`).
