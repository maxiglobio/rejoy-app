#!/usr/bin/env node
/**
 * Migrates existing avatar images from teacher-portraits root to avatars/ subfolder.
 * Run: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node migrate-avatars-to-supabase.js
 *
 * Moves: {userId}.jpg → avatars/{userId}.jpg
 * Updates profiles.avatar_url and profiles.teacher_portrait_url to point to new path.
 */

import { createClient } from '@supabase/supabase-js';

const BUCKET = 'teacher-portraits';
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$/i;

async function main() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !key) {
    console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.');
    process.exit(1);
  }

  const supabase = createClient(url, key);

  // List root-level files (exclude avatars/ folder)
  const { data: rootFiles, error: listError } = await supabase.storage
    .from(BUCKET)
    .list('', { limit: 1000 });

  if (listError) {
    console.error('Failed to list storage:', listError.message);
    process.exit(1);
  }

  const toMove = (rootFiles || []).filter(
    (f) => f.name && f.name.endsWith('.jpg') && UUID_REGEX.test(f.name)
  );

  if (toMove.length === 0) {
    console.log('No avatar files found at root to migrate.');
    return;
  }

  console.log(`Found ${toMove.length} avatar file(s) to move.`);

  for (const file of toMove) {
    const fromPath = file.name;
    const toPath = `avatars/${file.name}`;

    const { error: moveError } = await supabase.storage
      .from(BUCKET)
      .move(fromPath, toPath);

    if (moveError) {
      console.error(`Failed to move ${fromPath}:`, moveError.message);
      continue;
    }
    console.log(`Moved: ${fromPath} → ${toPath}`);
  }

  // Update profiles: set avatar_url and teacher_portrait_url to new path for affected users
  const userIds = toMove.map((f) => f.name.replace('.jpg', ''));
  const { data: profiles, error: profilesError } = await supabase
    .from('profiles')
    .select('id, teacher_portrait_url')
    .in('id', userIds.map((id) => id));

  if (profilesError) {
    console.error('Failed to fetch profiles:', profilesError.message);
    return;
  }

  const baseUrl = new URL(url);
  const storageBase = `${baseUrl.origin}/storage/v1/object/public/${BUCKET}`;

  for (const profile of profiles || []) {
    const newUrl = `${storageBase}/avatars/${profile.id}.jpg`;
    const updates = {
      avatar_url: newUrl,
      updated_at: new Date().toISOString(),
    };
    // If they had teacher_portrait_url (old path), point it to new location too
    if (profile.teacher_portrait_url) {
      updates.teacher_portrait_url = newUrl;
    }
    const { error: updateError } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', profile.id);

    if (updateError) {
      console.error(`Failed to update profile ${profile.id}:`, updateError.message);
    } else {
      console.log(`Updated profile ${profile.id} with new avatar URL`);
    }
  }

  console.log('Migration complete.');
}

main().catch(console.error);
