# Supabase Setup for Rejoy

## 1. Run the SQL Migration

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project
2. Go to **SQL Editor** → New query
3. Copy the contents of `Rejoy/Supabase/migrations/001_initial_schema.sql`
4. Run the query

## 2. Enable Sign in with Apple in Supabase

1. In Supabase Dashboard → **Authentication** → **Providers**
2. Enable **Apple**
3. For native iOS apps, you typically need:
   - **Services ID** (optional for native-only)
   - **App Bundle ID**: `com.globio.rejoy`

See [Supabase Apple Auth docs](https://supabase.com/docs/guides/auth/social-login/auth-apple?platform=swift) for full configuration.

## 3. Add Sign in with Apple Capability in Xcode

1. Select the Rejoy target → **Signing & Capabilities**
2. Click **+ Capability**
3. Add **Sign in with Apple**

## 4. Credentials (already configured)

- **Project URL**: `https://jvjsdcynjaamqfwkzpwf.supabase.co`
- **Publishable Key**: Stored in `SupabaseClient.swift`

**Note**: Do not commit the database password. The direct connection string is for server-side use only.

## 5. Next Steps (to wire up)

- Add "Sign in with Apple" button to WelcomeView
- Sync sessions to Supabase when user is signed in (in DedicationView after save)
- Fetch and merge remote sessions on app launch
