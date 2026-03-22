# Rejoy migration scripts

## migrate-avatars-to-supabase.js

Moves existing avatar images from `teacher-portraits` root (`{userId}.jpg`) to `avatars/{userId}.jpg` and updates `profiles.avatar_url` and `profiles.teacher_portrait_url` accordingly.

**Prerequisites:**
- Node.js 18+
- Migration `011_avatar_url.sql` applied (adds `avatar_url` column and storage policies for `avatars/`)

**Run:**
```bash
cd scripts
npm install
SUPABASE_URL=https://YOUR_PROJECT.supabase.co SUPABASE_SERVICE_ROLE_KEY=your_service_role_key node migrate-avatars-to-supabase.js
```

Get your project URL and service role key from Supabase Dashboard → Project Settings → API.
