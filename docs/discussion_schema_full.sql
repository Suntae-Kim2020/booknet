-- =====================================================
-- 독서토론 통합 마이그레이션 (컬럼 + 테이블 + RLS 한 번에)
-- Supabase SQL Editor에서 그대로 Run
-- 여러 번 실행해도 안전합니다 (idempotent).
-- =====================================================

-- ========== 0. discussions 테이블이 아예 없으면 생성 ==========
create table if not exists discussions (
    id text primary key,
    host_id uuid not null references auth.users(id) on delete cascade,
    book_id text references books(id),
    title text not null,
    scheduled_at timestamptz not null,
    created_at timestamptz default now()
);

-- ========== 1. discussions 컬럼 보강 ==========
alter table discussions add column if not exists description text;
alter table discussions add column if not exists region text;
alter table discussions add column if not exists is_online boolean default false;
alter table discussions add column if not exists online_url text;
alter table discussions add column if not exists max_participants integer default 10;
alter table discussions add column if not exists current_participants integer default 1;
alter table discussions add column if not exists gender_policy text default 'any';
alter table discussions add column if not exists min_age integer;
alter table discussions add column if not exists max_age integer;
alter table discussions add column if not exists status text default 'open';
alter table discussions add column if not exists recurrence text default 'one_time';
alter table discussions add column if not exists approval_mode text default 'auto';
alter table discussions add column if not exists rules text;
alter table discussions add column if not exists current_book_id text references books(id);
alter table discussions add column if not exists current_moderator_id uuid references auth.users(id);

create index if not exists discussions_region_idx on discussions(region);
create index if not exists discussions_book_idx on discussions(book_id);
create index if not exists discussions_online_idx on discussions(is_online);

-- ========== 2. discussion_participants 테이블 + 컬럼 ==========
create table if not exists discussion_participants (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    status text default 'joined',
    joined_at timestamptz default now(),
    unique(discussion_id, user_id)
);
alter table discussion_participants add column if not exists role text default 'member';

-- ========== 3. discussion_interests ==========
create table if not exists discussion_interests (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    book_id text not null references books(id),
    created_at timestamptz default now(),
    unique(user_id, book_id)
);

-- ========== 4. discussion_books ==========
create table if not exists discussion_books (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    book_id text not null references books(id),
    status text not null default 'scheduled',
    scheduled_at timestamptz,
    moderator_id uuid references auth.users(id),
    created_at timestamptz default now(),
    unique(discussion_id, book_id)
);
create index if not exists discussion_books_disc_idx on discussion_books(discussion_id);

-- ========== 5. discussion_book_candidates ==========
create table if not exists discussion_book_candidates (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    book_id text not null references books(id),
    suggested_by uuid references auth.users(id),
    vote_ends_at timestamptz,
    is_closed boolean default false,
    created_at timestamptz default now(),
    unique(discussion_id, book_id)
);

-- ========== 6. discussion_votes ==========
create table if not exists discussion_votes (
    id uuid primary key default gen_random_uuid(),
    candidate_id uuid not null references discussion_book_candidates(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz default now(),
    unique(candidate_id, user_id)
);

-- ========== 7. discussion_meetings ==========
create table if not exists discussion_meetings (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    book_id text references books(id),
    scheduled_at timestamptz not null,
    ended_at timestamptz,
    moderator_id uuid references auth.users(id),
    location text,
    online_url text,
    notes text,
    created_at timestamptz default now()
);
create index if not exists discussion_meetings_disc_idx on discussion_meetings(discussion_id, scheduled_at desc);

-- ========== 8. discussion_attendance ==========
create table if not exists discussion_attendance (
    id uuid primary key default gen_random_uuid(),
    meeting_id uuid not null references discussion_meetings(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    status text default 'present',
    presentation_order integer,
    created_at timestamptz default now(),
    unique(meeting_id, user_id)
);

-- ========== 9. discussion_topics ==========
create table if not exists discussion_topics (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    book_id text references books(id),
    meeting_id uuid references discussion_meetings(id) on delete cascade,
    content text not null,
    author_id uuid references auth.users(id),
    created_at timestamptz default now()
);
create index if not exists discussion_topics_disc_idx on discussion_topics(discussion_id, created_at desc);

-- ========== 10. discussion_notes ==========
create table if not exists discussion_notes (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    meeting_id uuid references discussion_meetings(id) on delete cascade,
    author_id uuid not null references auth.users(id),
    content text not null,
    created_at timestamptz default now()
);
create index if not exists discussion_notes_disc_idx on discussion_notes(discussion_id, created_at desc);

-- ========== 11. discussion_quotes ==========
create table if not exists discussion_quotes (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    book_id text references books(id),
    author_id uuid not null references auth.users(id),
    content text not null,
    page_number integer,
    created_at timestamptz default now()
);

-- ========== 12. discussion_announcements ==========
create table if not exists discussion_announcements (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    author_id uuid not null references auth.users(id),
    title text not null,
    content text,
    is_pinned boolean default false,
    created_at timestamptz default now()
);

-- ========== 13. discussion_join_requests ==========
create table if not exists discussion_join_requests (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    message text,
    status text default 'pending',
    created_at timestamptz default now(),
    unique(discussion_id, user_id)
);

-- ========== 14. discussion_chat ==========
create table if not exists discussion_chat (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    sender_id uuid not null references auth.users(id) on delete cascade,
    content text not null,
    reply_to uuid references discussion_chat(id),
    created_at timestamptz default now()
);
alter table discussion_chat add column if not exists reply_to uuid references discussion_chat(id);
create index if not exists discussion_chat_disc_idx on discussion_chat(discussion_id, created_at);

-- ========== RLS 활성화 ==========
alter table discussions enable row level security;
alter table discussion_participants enable row level security;
alter table discussion_interests enable row level security;
alter table discussion_books enable row level security;
alter table discussion_book_candidates enable row level security;
alter table discussion_votes enable row level security;
alter table discussion_meetings enable row level security;
alter table discussion_attendance enable row level security;
alter table discussion_topics enable row level security;
alter table discussion_notes enable row level security;
alter table discussion_quotes enable row level security;
alter table discussion_announcements enable row level security;
alter table discussion_join_requests enable row level security;
alter table discussion_chat enable row level security;

-- ========== 정책 (재실행 안전하게 drop 후 create) ==========

-- discussions
drop policy if exists "discussions_read" on discussions;
create policy "discussions_read" on discussions for select using (true);
drop policy if exists "discussions_write" on discussions;
create policy "discussions_write" on discussions
    for insert with check (auth.uid() = host_id);
drop policy if exists "discussions_update" on discussions;
create policy "discussions_update" on discussions
    for update using (auth.uid() = host_id);
drop policy if exists "discussions_delete" on discussions;
create policy "discussions_delete" on discussions
    for delete using (auth.uid() = host_id);

-- discussion_participants
drop policy if exists "discussion_participants_read" on discussion_participants;
create policy "discussion_participants_read" on discussion_participants
    for select using (true);
drop policy if exists "discussion_participants_write" on discussion_participants;
create policy "discussion_participants_write" on discussion_participants
    for insert with check (auth.uid() = user_id);
drop policy if exists "discussion_participants_update" on discussion_participants;
create policy "discussion_participants_update" on discussion_participants
    for update using (auth.uid() = user_id);
drop policy if exists "discussion_participants_delete" on discussion_participants;
create policy "discussion_participants_delete" on discussion_participants
    for delete using (
        auth.uid() = user_id or
        exists (select 1 from discussions
                where id = discussion_participants.discussion_id
                  and host_id = auth.uid())
    );

-- discussion_interests
drop policy if exists "discussion_interests_read" on discussion_interests;
create policy "discussion_interests_read" on discussion_interests
    for select using (true);
drop policy if exists "discussion_interests_write" on discussion_interests;
create policy "discussion_interests_write" on discussion_interests
    for insert with check (auth.uid() = user_id);
drop policy if exists "discussion_interests_delete" on discussion_interests;
create policy "discussion_interests_delete" on discussion_interests
    for delete using (auth.uid() = user_id);

-- discussion_books
drop policy if exists "discussion_books_read" on discussion_books;
create policy "discussion_books_read" on discussion_books
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_books.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "discussion_books_write" on discussion_books;
create policy "discussion_books_write" on discussion_books
    for all using (
        exists (select 1 from discussions
                where id = discussion_books.discussion_id
                  and host_id = auth.uid())
    ) with check (
        exists (select 1 from discussions
                where id = discussion_books.discussion_id
                  and host_id = auth.uid())
    );

-- discussion_book_candidates
drop policy if exists "disc_candidates_read" on discussion_book_candidates;
create policy "disc_candidates_read" on discussion_book_candidates
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_book_candidates.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_candidates_write" on discussion_book_candidates;
create policy "disc_candidates_write" on discussion_book_candidates
    for insert with check (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_book_candidates.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_candidates_update" on discussion_book_candidates;
create policy "disc_candidates_update" on discussion_book_candidates
    for update using (
        exists (select 1 from discussions
                where id = discussion_book_candidates.discussion_id
                  and host_id = auth.uid())
    );
drop policy if exists "disc_candidates_delete" on discussion_book_candidates;
create policy "disc_candidates_delete" on discussion_book_candidates
    for delete using (
        exists (select 1 from discussions
                where id = discussion_book_candidates.discussion_id
                  and host_id = auth.uid())
    );

-- discussion_votes
drop policy if exists "disc_votes_read" on discussion_votes;
create policy "disc_votes_read" on discussion_votes for select using (true);
drop policy if exists "disc_votes_write" on discussion_votes;
create policy "disc_votes_write" on discussion_votes
    for insert with check (auth.uid() = user_id);
drop policy if exists "disc_votes_delete" on discussion_votes;
create policy "disc_votes_delete" on discussion_votes
    for delete using (auth.uid() = user_id);

-- discussion_meetings
drop policy if exists "disc_meetings_read" on discussion_meetings;
create policy "disc_meetings_read" on discussion_meetings
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_meetings.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_meetings_write" on discussion_meetings;
create policy "disc_meetings_write" on discussion_meetings
    for all using (
        exists (select 1 from discussions
                where id = discussion_meetings.discussion_id
                  and host_id = auth.uid())
    ) with check (
        exists (select 1 from discussions
                where id = discussion_meetings.discussion_id
                  and host_id = auth.uid())
    );

-- discussion_attendance
drop policy if exists "disc_attendance_read" on discussion_attendance;
create policy "disc_attendance_read" on discussion_attendance
    for select using (
        exists (select 1 from discussion_meetings m
                join discussion_participants p on p.discussion_id = m.discussion_id
                where m.id = discussion_attendance.meeting_id
                  and p.user_id = auth.uid())
    );
drop policy if exists "disc_attendance_write" on discussion_attendance;
create policy "disc_attendance_write" on discussion_attendance
    for insert with check (auth.uid() = user_id);
drop policy if exists "disc_attendance_update" on discussion_attendance;
create policy "disc_attendance_update" on discussion_attendance
    for update using (auth.uid() = user_id);

-- discussion_topics
drop policy if exists "disc_topics_read" on discussion_topics;
create policy "disc_topics_read" on discussion_topics
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_topics.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_topics_write" on discussion_topics;
create policy "disc_topics_write" on discussion_topics
    for insert with check (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_topics.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_topics_delete" on discussion_topics;
create policy "disc_topics_delete" on discussion_topics
    for delete using (auth.uid() = author_id);

-- discussion_notes
drop policy if exists "disc_notes_read" on discussion_notes;
create policy "disc_notes_read" on discussion_notes
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_notes.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_notes_write" on discussion_notes;
create policy "disc_notes_write" on discussion_notes
    for insert with check (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_notes.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_notes_update" on discussion_notes;
create policy "disc_notes_update" on discussion_notes
    for update using (auth.uid() = author_id);
drop policy if exists "disc_notes_delete" on discussion_notes;
create policy "disc_notes_delete" on discussion_notes
    for delete using (auth.uid() = author_id);

-- discussion_quotes
drop policy if exists "disc_quotes_read" on discussion_quotes;
create policy "disc_quotes_read" on discussion_quotes
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_quotes.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_quotes_write" on discussion_quotes;
create policy "disc_quotes_write" on discussion_quotes
    for insert with check (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_quotes.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_quotes_delete" on discussion_quotes;
create policy "disc_quotes_delete" on discussion_quotes
    for delete using (auth.uid() = author_id);

-- discussion_announcements
drop policy if exists "disc_announce_read" on discussion_announcements;
create policy "disc_announce_read" on discussion_announcements
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_announcements.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_announce_write" on discussion_announcements;
create policy "disc_announce_write" on discussion_announcements
    for all using (
        exists (select 1 from discussions
                where id = discussion_announcements.discussion_id
                  and host_id = auth.uid())
    ) with check (
        exists (select 1 from discussions
                where id = discussion_announcements.discussion_id
                  and host_id = auth.uid())
    );

-- discussion_join_requests
drop policy if exists "disc_join_read" on discussion_join_requests;
create policy "disc_join_read" on discussion_join_requests
    for select using (
        auth.uid() = user_id or
        exists (select 1 from discussions
                where id = discussion_join_requests.discussion_id
                  and host_id = auth.uid())
    );
drop policy if exists "disc_join_write" on discussion_join_requests;
create policy "disc_join_write" on discussion_join_requests
    for insert with check (auth.uid() = user_id);
drop policy if exists "disc_join_update" on discussion_join_requests;
create policy "disc_join_update" on discussion_join_requests
    for update using (
        exists (select 1 from discussions
                where id = discussion_join_requests.discussion_id
                  and host_id = auth.uid())
    );

-- discussion_chat
drop policy if exists "disc_chat_read" on discussion_chat;
create policy "disc_chat_read" on discussion_chat
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_chat.discussion_id
                  and user_id = auth.uid())
    );
drop policy if exists "disc_chat_write" on discussion_chat;
create policy "disc_chat_write" on discussion_chat
    for insert with check (
        auth.uid() = sender_id and
        exists (select 1 from discussion_participants
                where discussion_id = discussion_chat.discussion_id
                  and user_id = auth.uid())
    );

-- ========== PostgREST 스키마 캐시 갱신 ==========
notify pgrst, 'reload schema';
