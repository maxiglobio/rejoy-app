# Push Notifications Setup for Nudges

This guide explains how to enable real push notifications when someone sends a nudge, so users are notified even when the app is closed.

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

```bash
cd /path/to/Rejoy
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"
supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"
supabase secrets set APNS_KEY_P8="$(cat /path/to/AuthKey_XXXXX.p8)"
supabase secrets set APNS_BUNDLE_ID="com.globio.rejoy"   # Your app bundle ID
supabase secrets set APNS_PRODUCTION="false"   # Use "true" for production/App Store
supabase functions deploy nudge-push --no-verify-jwt
```

## 4. Create the Database Webhook

1. In Supabase Dashboard → Database → Webhooks
2. Create webhook
3. **Table**: `public.activity_nudges`
4. **Events**: Insert
5. **Type**: Supabase Edge Function
6. **Function**: `nudge-push`
7. **HTTP Headers**: Add auth header with service role key

## 5. iOS: Push Notifications capability

The entitlements file already includes `aps-environment`. Ensure your Xcode project has the **Push Notifications** capability enabled:

1. Select the Rejoy target
2. Signing & Capabilities → + Capability → Push Notifications

For production (App Store) builds, change `aps-environment` in Rejoy.entitlements to `production` or use a build configuration.

## 6. Test

1. Build and run on a **physical device** (push does not work on simulator)
2. Sign in and grant notification permission
3. Have another user send you a nudge
4. You should receive a push notification even when the app is in the background or closed
