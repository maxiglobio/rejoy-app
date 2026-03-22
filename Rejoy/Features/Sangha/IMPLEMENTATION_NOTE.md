# Sangha Social Layer – Implementation Note

## Architecture Decisions

- **SanghaService**: Central `@MainActor` service for all Sangha operations. Uses Supabase client directly (same as SupabaseService). No SwiftData for social entities.
- **One Sangha per user (v1)**: `fetchMySangha()` returns the first/only Sangha the user belongs to.
- **Invite via RPC**: `join_sangha_by_code(p_invite_code)` is a `SECURITY DEFINER` function that bypasses RLS to safely validate the code and insert the member. This avoids exposing sangha data to unauthenticated lookups.
- **Sessions RLS**: Added policy so Sangha members can read each other's sessions for the story viewer. Users still can only insert/update/delete their own sessions.
- **Active tracking**: Stored in `active_tracking_state`. On tracker start → upsert; on stop → delete. Avatar strip polls every 15 seconds.

## Assumptions

- **Supabase auth**: User must be signed in for any Sangha features. Guest users see no Sangha UI.
- **Sessions sync**: Sessions are local-first (SwiftData); Supabase has sessions only when the user is signed in. Sangha members see Supabase data only—no local sessions from other devices.
- **Avatars**: No per-user avatar URLs in Supabase. Use `ProfileState` for self; initials for others until avatar storage is added.
- **Activity types**: Story viewer uses local `ActivityType` from SwiftData to resolve names/symbols. If another member uses a custom activity we don't have locally, we fall back to "Activity".

## Tradeoffs

- **Polling vs Realtime**: v1 uses 15s polling for `active_tracking_state`. Supabase Realtime would reduce latency but adds complexity; deferred to Phase 2.
- **Deep link**: Plan mentions `rejoy://sangha/join?code=X`. Not configured in Info.plist for v1; ShareLink uses `https://rejoy.app/sangha/join?code=X`. User can paste code in JoinSanghaSheet.
- **Member display names**: No `profiles` display_name for other users. Using "Member" for non-self until we add profile fetching.

## Phase 2 Recommendations

1. **Supabase Realtime** for `active_tracking_state` to remove polling.
2. **Richer story cards**: Dedication text, more metadata.
3. **Multi-Sangha support**: Allow users to belong to multiple Sanghas; add Sangha picker.
4. **Creator/admin permissions**: Manage members, remove users, transfer ownership.
5. **Avatar storage**: Store member avatars in Supabase storage; fetch for story/avatar strip.
6. **Deep link handling**: Configure `rejoy://` URL scheme and handle `/sangha/join?code=` to open JoinSanghaSheet directly.
