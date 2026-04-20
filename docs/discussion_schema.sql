-- =====================================================
-- 독서토론 모임 확장 스키마
-- Supabase SQL Editor에서 실행
-- =====================================================

-- ========== 1. discussions 확장 ==========
alter table discussions add column if not exists description text;
alter table discussions add column if not exists online_url text;
alter table discussions add column if not exists recurrence text default 'one_time';
    -- 'one_time' / 'weekly' / 'monthly'
alter table discussions add column if not exists approval_mode text default 'auto';
    -- 'auto' (즉시 가입) / 'manual' (호스트 승인)
alter table discussions add column if not exists rules text;
alter table discussions add column if not exists current_book_id text references books(id);
alter table discussions add column if not exists current_moderator_id uuid references auth.users(id);

-- ========== 2. discussion_participants 확장 (역할) ==========
alter table discussion_participants add column if not exists role text default 'member';
    -- 'host' / 'moderator' / 'member'

-- ========== 3. discussion_books (토론했던/할 책 아카이브) ==========
create table if not exists discussion_books (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    book_id text not null references books(id),
    status text not null default 'scheduled',
        -- 'scheduled' (예정) / 'current' (현재) / 'completed' (완료)
    scheduled_at timestamptz,
    moderator_id uuid references auth.users(id),
    created_at timestamptz default now(),
    unique(discussion_id, book_id)
);
create index if not exists discussion_books_disc_idx on discussion_books(discussion_id);

-- ========== 4. discussion_book_candidates (다음 도서 후보) ==========
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

-- ========== 5. discussion_votes (후보 투표) ==========
create table if not exists discussion_votes (
    id uuid primary key default gen_random_uuid(),
    candidate_id uuid not null references discussion_book_candidates(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz default now(),
    unique(candidate_id, user_id)
);

-- ========== 6. discussion_meetings (모임 일정 + 출석) ==========
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

-- ========== 7. discussion_attendance (출석체크) ==========
create table if not exists discussion_attendance (
    id uuid primary key default gen_random_uuid(),
    meeting_id uuid not null references discussion_meetings(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    status text default 'present',  -- 'present' / 'absent' / 'late'
    presentation_order integer,
    created_at timestamptz default now(),
    unique(meeting_id, user_id)
);

-- ========== 8. discussion_topics (토론 주제/질문) ==========
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

-- ========== 9. discussion_notes (공유 메모/후기) ==========
create table if not exists discussion_notes (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    meeting_id uuid references discussion_meetings(id) on delete cascade,
    author_id uuid not null references auth.users(id),
    content text not null,
    created_at timestamptz default now()
);
create index if not exists discussion_notes_disc_idx on discussion_notes(discussion_id, created_at desc);

-- ========== 10. discussion_quotes (인상깊은 구절) ==========
create table if not exists discussion_quotes (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    book_id text references books(id),
    author_id uuid not null references auth.users(id),
    content text not null,
    page_number integer,
    created_at timestamptz default now()
);

-- ========== 11. discussion_announcements (공지) ==========
create table if not exists discussion_announcements (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    author_id uuid not null references auth.users(id),
    title text not null,
    content text,
    is_pinned boolean default false,
    created_at timestamptz default now()
);

-- ========== 12. discussion_join_requests (가입 승인 대기) ==========
create table if not exists discussion_join_requests (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    message text,
    status text default 'pending',  -- 'pending' / 'accepted' / 'rejected'
    created_at timestamptz default now(),
    unique(discussion_id, user_id)
);

-- ========== 13. discussion_chat (모임 채팅) ==========
create table if not exists discussion_chat (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    sender_id uuid not null references auth.users(id) on delete cascade,
    content text not null,
    created_at timestamptz default now()
);
create index if not exists discussion_chat_disc_idx on discussion_chat(discussion_id, created_at);

-- ========== RLS ==========
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

-- 참가자만 접근하는 헬퍼: user_id가 참여자인지 체크
-- (RLS에서는 함수 대신 subquery 사용)

-- discussion_books: 참가자 읽기, 호스트만 쓰기
create policy "discussion_books_read" on discussion_books
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_books.discussion_id
                  and user_id = auth.uid())
    );
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

-- discussion_book_candidates: 참가자 모두 읽기/쓰기
create policy "disc_candidates_read" on discussion_book_candidates
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_book_candidates.discussion_id
                  and user_id = auth.uid())
    );
create policy "disc_candidates_write" on discussion_book_candidates
    for insert with check (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_book_candidates.discussion_id
                  and user_id = auth.uid())
    );
create policy "disc_candidates_update" on discussion_book_candidates
    for update using (
        exists (select 1 from discussions
                where id = discussion_book_candidates.discussion_id
                  and host_id = auth.uid())
    );
create policy "disc_candidates_delete" on discussion_book_candidates
    for delete using (
        exists (select 1 from discussions
                where id = discussion_book_candidates.discussion_id
                  and host_id = auth.uid())
    );

-- discussion_votes: 본인 투표만
create policy "disc_votes_read" on discussion_votes
    for select using (true);
create policy "disc_votes_write" on discussion_votes
    for insert with check (auth.uid() = user_id);
create policy "disc_votes_delete" on discussion_votes
    for delete using (auth.uid() = user_id);

-- discussion_meetings: 참가자 읽기, 호스트만 쓰기
create policy "disc_meetings_read" on discussion_meetings
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_meetings.discussion_id
                  and user_id = auth.uid())
    );
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

-- discussion_attendance: 본인 것만 쓰기, 참가자 읽기
create policy "disc_attendance_read" on discussion_attendance
    for select using (
        exists (select 1 from discussion_meetings m
                join discussion_participants p on p.discussion_id = m.discussion_id
                where m.id = discussion_attendance.meeting_id
                  and p.user_id = auth.uid())
    );
create policy "disc_attendance_write" on discussion_attendance
    for insert with check (auth.uid() = user_id);
create policy "disc_attendance_update" on discussion_attendance
    for update using (auth.uid() = user_id);

-- discussion_topics: 참가자 모두 읽기/쓰기
create policy "disc_topics_read" on discussion_topics
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_topics.discussion_id
                  and user_id = auth.uid())
    );
create policy "disc_topics_write" on discussion_topics
    for insert with check (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_topics.discussion_id
                  and user_id = auth.uid())
    );
create policy "disc_topics_delete" on discussion_topics
    for delete using (auth.uid() = author_id);

-- discussion_notes: 참가자 모두 읽기/쓰기
create policy "disc_notes_read" on discussion_notes
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_notes.discussion_id
                  and user_id = auth.uid())
    );
create policy "disc_notes_write" on discussion_notes
    for insert with check (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_notes.discussion_id
                  and user_id = auth.uid())
    );
create policy "disc_notes_update" on discussion_notes
    for update using (auth.uid() = author_id);
create policy "disc_notes_delete" on discussion_notes
    for delete using (auth.uid() = author_id);

-- discussion_quotes: 참가자 모두 읽기/쓰기
create policy "disc_quotes_read" on discussion_quotes
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_quotes.discussion_id
                  and user_id = auth.uid())
    );
create policy "disc_quotes_write" on discussion_quotes
    for insert with check (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_quotes.discussion_id
                  and user_id = auth.uid())
    );
create policy "disc_quotes_delete" on discussion_quotes
    for delete using (auth.uid() = author_id);

-- discussion_announcements: 참가자 읽기, 호스트만 쓰기
create policy "disc_announce_read" on discussion_announcements
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_announcements.discussion_id
                  and user_id = auth.uid())
    );
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

-- discussion_join_requests: 본인/호스트만 접근
create policy "disc_join_read" on discussion_join_requests
    for select using (
        auth.uid() = user_id or
        exists (select 1 from discussions
                where id = discussion_join_requests.discussion_id
                  and host_id = auth.uid())
    );
create policy "disc_join_write" on discussion_join_requests
    for insert with check (auth.uid() = user_id);
create policy "disc_join_update" on discussion_join_requests
    for update using (
        exists (select 1 from discussions
                where id = discussion_join_requests.discussion_id
                  and host_id = auth.uid())
    );

-- discussion_chat: 참가자만
create policy "disc_chat_read" on discussion_chat
    for select using (
        exists (select 1 from discussion_participants
                where discussion_id = discussion_chat.discussion_id
                  and user_id = auth.uid())
    );
create policy "disc_chat_write" on discussion_chat
    for insert with check (
        auth.uid() = sender_id and
        exists (select 1 from discussion_participants
                where discussion_id = discussion_chat.discussion_id
                  and user_id = auth.uid())
    );

-- discussions 삭제 정책 추가
create policy if not exists "discussions_delete" on discussions
    for delete using (auth.uid() = host_id);

-- discussion_participants 삭제 정책 (본인 탈퇴 / 호스트 강퇴)
create policy if not exists "discussion_participants_delete" on discussion_participants
    for delete using (
        auth.uid() = user_id or
        exists (select 1 from discussions
                where id = discussion_participants.discussion_id
                  and host_id = auth.uid())
    );
