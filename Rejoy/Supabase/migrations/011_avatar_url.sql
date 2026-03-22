-- Add avatar_url for user profile photo (Sangha avatars). Separate from teacher_portrait_url (Altar/meditation teacher).
-- Run in Supabase Dashboard → SQL Editor

alter table public.profiles add column if not exists avatar_url text;

-- Storage: use same bucket "teacher-portraits" with path "avatars/{userId}.jpg" for user avatars.
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'teacher-portraits'
  AND name = 'avatars/' || (auth.uid())::text || '.jpg'
);

CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'teacher-portraits'
  AND name = 'avatars/' || (auth.uid())::text || '.jpg'
);

CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'teacher-portraits'
  AND name = 'avatars/' || (auth.uid())::text || '.jpg'
);
