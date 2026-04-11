-- Booknet Supabase 스키마
-- Supabase SQL Editor에서 실행하세요.

create extension if not exists "pgcrypto";

-- ============ profiles ============
create table if not exists profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    nickname text,
    avatar_url text,
    region text,
    gender text,                          -- 'male' / 'female' / null
    birth_year integer,
    phone text,
    kakao_id text,
    sharing_default text default 'all',   -- 'all' / 'friends' / 'none'
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============ books ============
create table if not exists books (
    id text primary key,
    owner_id uuid not null references auth.users(id) on delete cascade,
    isbn text,
    title text not null,
    author text,
    publisher text,
    cover_url text,
    description text,
    published_at date,
    is_read boolean default false,
    is_for_sale boolean default false,
    wants_discussion boolean default false,
    read_at timestamptz,
    created_at timestamptz default now()
);
create index if not exists books_owner_idx on books(owner_id);
create index if not exists books_isbn_idx on books(isbn);

-- ============ memos ============
create table if not exists memos (
    id uuid primary key default gen_random_uuid(),
    book_id text not null references books(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    content text not null,
    page_number integer,
    is_shared boolean default true,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);
create index if not exists memos_book_user_idx on memos(book_id, user_id);
create index if not exists memos_content_idx on memos using gin(to_tsvector('simple', content));

-- ============ sale_bundles ============
create table if not exists sale_bundles (
    id text primary key,
    owner_id uuid not null references auth.users(id) on delete cascade,
    title text not null,
    description text,
    status text not null default 'listed', -- listed / reserved / sold / hidden
    created_at timestamptz default now()
);
create index if not exists bundles_owner_idx on sale_bundles(owner_id);
create index if not exists bundles_status_idx on sale_bundles(status);

-- ============ bundle_books (개별 책 가격) ============
create table if not exists bundle_books (
    id uuid primary key default gen_random_uuid(),
    bundle_id text not null references sale_bundles(id) on delete cascade,
    book_id text not null references books(id) on delete cascade,
    price_won integer not null default 0,
    unique(bundle_id, book_id)
);
create index if not exists bundle_books_bundle_idx on bundle_books(bundle_id);

-- ============ purchase_requests ============
create table if not exists purchase_requests (
    id uuid primary key default gen_random_uuid(),
    bundle_id text not null references sale_bundles(id) on delete cascade,
    buyer_id uuid not null references auth.users(id) on delete cascade,
    selected_book_ids text[] not null,
    total_price_won integer not null,
    delivery_method text default 'delivery', -- 'delivery' / 'in_person'
    status text default 'pending',           -- pending / accepted / rejected / completed
    message text,
    created_at timestamptz default now()
);
create index if not exists purchase_requests_bundle_idx on purchase_requests(bundle_id);
create index if not exists purchase_requests_buyer_idx on purchase_requests(buyer_id);

-- ============ chat_rooms ============
create table if not exists chat_rooms (
    id uuid primary key default gen_random_uuid(),
    purchase_request_id uuid references purchase_requests(id),
    participant_ids uuid[] not null,
    last_message_at timestamptz,
    created_at timestamptz default now()
);
create index if not exists chat_rooms_participants_idx on chat_rooms using gin(participant_ids);

-- ============ chat_messages ============
create table if not exists chat_messages (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references chat_rooms(id) on delete cascade,
    sender_id uuid not null references auth.users(id),
    content text not null,
    message_type text default 'text', -- text / price_offer / delivery_choice / image
    metadata jsonb,
    read_at timestamptz,
    created_at timestamptz default now()
);
create index if not exists chat_messages_room_idx on chat_messages(room_id, created_at);

-- ============ discussions ============
create table if not exists discussions (
    id text primary key,
    host_id uuid not null references auth.users(id) on delete cascade,
    book_id text references books(id),
    title text not null,
    description text,
    region text,
    is_online boolean default false,
    scheduled_at timestamptz not null,
    max_participants integer default 10,
    current_participants integer default 1,
    gender_policy text default 'any',  -- 'male_only' / 'female_only' / 'any'
    min_age integer,
    max_age integer,
    status text default 'open',        -- 'open' / 'closed' / 'completed'
    created_at timestamptz default now()
);
create index if not exists discussions_region_idx on discussions(region);
create index if not exists discussions_book_idx on discussions(book_id);
create index if not exists discussions_online_idx on discussions(is_online);

-- ============ discussion_participants ============
create table if not exists discussion_participants (
    id uuid primary key default gen_random_uuid(),
    discussion_id text not null references discussions(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    status text default 'joined', -- 'joined' / 'left' / 'kicked'
    joined_at timestamptz default now(),
    unique(discussion_id, user_id)
);

-- ============ discussion_interests (자동 알림 매칭) ============
create table if not exists discussion_interests (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    book_id text not null references books(id) on delete cascade,
    region text,
    is_online_ok boolean default true,
    is_offline_ok boolean default true,
    created_at timestamptz default now(),
    unique(user_id, book_id)
);
create index if not exists discussion_interests_book_idx on discussion_interests(book_id);

-- ============ reviews (한 줄 평) ============
create table if not exists reviews (
    id text primary key,
    book_id text references books(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    content text not null check (char_length(content) <= 280),
    rating integer check (rating between 1 and 5),
    created_at timestamptz default now()
);
create index if not exists reviews_book_idx on reviews(book_id);
create index if not exists reviews_recent_idx on reviews(created_at desc);

-- ============ notifications ============
create table if not exists notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    type text not null,     -- discussion_match / purchase_request / chat_message / bundle_sold
    title text not null,
    body text,
    data jsonb,
    channel text default 'in_app', -- in_app / kakao / sms / push
    is_read boolean default false,
    created_at timestamptz default now()
);
create index if not exists notifications_user_idx on notifications(user_id, created_at desc);

-- ============ Row Level Security ============
alter table profiles enable row level security;
alter table books enable row level security;
alter table memos enable row level security;
alter table sale_bundles enable row level security;
alter table bundle_books enable row level security;
alter table purchase_requests enable row level security;
alter table chat_rooms enable row level security;
alter table chat_messages enable row level security;
alter table discussions enable row level security;
alter table discussion_participants enable row level security;
alter table discussion_interests enable row level security;
alter table reviews enable row level security;
alter table notifications enable row level security;

-- profiles: 본인만 수정, 공개 읽기
create policy "profiles_read" on profiles for select using (true);
create policy "profiles_write" on profiles
    for all using (auth.uid() = id) with check (auth.uid() = id);

-- books: 본인 소유 데이터만 읽기/쓰기
create policy "books_owner" on books
    for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

-- memos: 공유 메모는 누구나 읽기, 작성/수정은 본인만
create policy "memos_read_shared" on memos
    for select using (is_shared = true or auth.uid() = user_id);
create policy "memos_write" on memos
    for insert with check (auth.uid() = user_id);
create policy "memos_update" on memos
    for update using (auth.uid() = user_id);
create policy "memos_delete" on memos
    for delete using (auth.uid() = user_id);

-- sale_bundles: 공개 읽기, 본인만 쓰기/수정
create policy "bundles_read" on sale_bundles for select using (true);
create policy "bundles_write" on sale_bundles
    for insert with check (auth.uid() = owner_id);
create policy "bundles_update" on sale_bundles
    for update using (auth.uid() = owner_id);

-- bundle_books: 공개 읽기 (꾸러미 열람), 꾸러미 소유자만 쓰기
create policy "bundle_books_read" on bundle_books for select using (true);
create policy "bundle_books_write" on bundle_books
    for insert with check (
        exists (select 1 from sale_bundles where id = bundle_id and owner_id = auth.uid())
    );
create policy "bundle_books_delete" on bundle_books
    for delete using (
        exists (select 1 from sale_bundles where id = bundle_id and owner_id = auth.uid())
    );

-- purchase_requests: 판매자와 구매자만 열람
create policy "purchase_requests_read" on purchase_requests
    for select using (
        auth.uid() = buyer_id or
        exists (select 1 from sale_bundles where id = bundle_id and owner_id = auth.uid())
    );
create policy "purchase_requests_write" on purchase_requests
    for insert with check (auth.uid() = buyer_id);
create policy "purchase_requests_update" on purchase_requests
    for update using (
        auth.uid() = buyer_id or
        exists (select 1 from sale_bundles where id = bundle_id and owner_id = auth.uid())
    );

-- chat_rooms: 참여자만 열람
create policy "chat_rooms_read" on chat_rooms
    for select using (auth.uid() = any(participant_ids));
create policy "chat_rooms_write" on chat_rooms
    for insert with check (auth.uid() = any(participant_ids));

-- chat_messages: 채팅방 참여자만 열람
create policy "chat_messages_read" on chat_messages
    for select using (
        exists (select 1 from chat_rooms where id = room_id and auth.uid() = any(participant_ids))
    );
create policy "chat_messages_write" on chat_messages
    for insert with check (auth.uid() = sender_id);

-- discussions: 누구나 검색, 작성/수정은 호스트만
create policy "discussions_read" on discussions for select using (true);
create policy "discussions_write" on discussions
    for insert with check (auth.uid() = host_id);
create policy "discussions_update" on discussions
    for update using (auth.uid() = host_id);

-- discussion_participants: 누구나 읽기, 본인만 참가/탈퇴
create policy "discussion_participants_read" on discussion_participants for select using (true);
create policy "discussion_participants_write" on discussion_participants
    for insert with check (auth.uid() = user_id);
create policy "discussion_participants_update" on discussion_participants
    for update using (auth.uid() = user_id);

-- discussion_interests: 본인 것만
create policy "discussion_interests_owner" on discussion_interests
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- reviews: 누구나 읽기, 작성은 본인만
create policy "reviews_read" on reviews for select using (true);
create policy "reviews_write" on reviews
    for insert with check (auth.uid() = user_id);

-- notifications: 본인 것만
create policy "notifications_owner" on notifications
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
