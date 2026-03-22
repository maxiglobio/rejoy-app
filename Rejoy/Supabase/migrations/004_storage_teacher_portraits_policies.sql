-- Rejoy: Storage policies for teacher-portraits bucket
-- Run this in Supabase Dashboard → SQL Editor
-- Prerequisite: Bucket "teacher-portraits" must exist and be public

-- Allow users to upload only their own file (path = {user_id}.jpg)
CREATE POLICY "Users can upload own teacher portrait"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'teacher-portraits'
  AND name = (auth.uid())::text || '.jpg'
);

-- Allow users to update only their own file
CREATE POLICY "Users can update own teacher portrait"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'teacher-portraits'
  AND name = (auth.uid())::text || '.jpg'
);

-- Allow users to delete only their own file
CREATE POLICY "Users can delete own teacher portrait"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'teacher-portraits'
  AND name = (auth.uid())::text || '.jpg'
);

-- Allow public read (needed for getPublicURL to work)
CREATE POLICY "Public read for teacher portraits"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'teacher-portraits');
