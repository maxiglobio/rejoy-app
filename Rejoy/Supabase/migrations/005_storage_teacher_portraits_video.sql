-- Rejoy: Allow video uploads in teacher-portraits bucket
-- Drops old .jpg-only policies and creates new ones for .jpg, .mp4, .mov

DROP POLICY IF EXISTS "Users can upload own teacher portrait" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own teacher portrait" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own teacher portrait" ON storage.objects;

CREATE POLICY "Users can upload own teacher portrait"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'teacher-portraits'
  AND (
    name = lower((auth.uid())::text) || '.jpg'
    OR name = lower((auth.uid())::text) || '.mp4'
    OR name = lower((auth.uid())::text) || '.mov'
  )
);

CREATE POLICY "Users can update own teacher portrait"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'teacher-portraits'
  AND (
    name = lower((auth.uid())::text) || '.jpg'
    OR name = lower((auth.uid())::text) || '.mp4'
    OR name = lower((auth.uid())::text) || '.mov'
  )
);

CREATE POLICY "Users can delete own teacher portrait"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'teacher-portraits'
  AND (
    name = lower((auth.uid())::text) || '.jpg'
    OR name = lower((auth.uid())::text) || '.mp4'
    OR name = lower((auth.uid())::text) || '.mov'
  )
);
