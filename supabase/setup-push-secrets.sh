#!/bin/bash
# Run this after: npx supabase login
# Usage: ./supabase/setup-push-secrets.sh

set -e
cd "$(dirname "$0")/.."

PROJECT_REF="jvjsdcynjaamqfwkzpwf"
TEAM_ID="DNSGKGK2JH"
KEY_ID="9NVZSUTG59"
P8_PATH="/Users/maximshishkin/Downloads/AuthKey_9NVZSUTG59.p8"

echo "Linking Supabase project..."
npx supabase link --project-ref "$PROJECT_REF"

echo "Setting secrets..."
npx supabase secrets set APNS_KEY_ID="$KEY_ID"
npx supabase secrets set APNS_TEAM_ID="$TEAM_ID"
npx supabase secrets set APNS_KEY_P8="$(cat "$P8_PATH")"
npx supabase secrets set APNS_BUNDLE_ID="com.globio.rejoy"
npx supabase secrets set APNS_PRODUCTION="false"

echo "Deploying nudge-push function..."
npx supabase functions deploy nudge-push --no-verify-jwt

echo "Done! Now create the webhook in Supabase Dashboard:"
echo "  Database → Webhooks → Create → Table: activity_nudges, Event: Insert, Function: nudge-push"
