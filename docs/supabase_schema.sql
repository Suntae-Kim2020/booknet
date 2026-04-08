-- Booknet Supabase 스키마
-- Supabase SQL Editor에서 실행하세요.

create extension if not exists "pgcrypto";

-- ============ books ============
create table if not exists books (
    id text primary key,
    owner_id uuid references auth.users(id) on delete cascade,
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

-- ============ sale_bundles ============
create table if not exists sale_bundles (
    id text primary key,
    owner_id uuid references auth.users(id) on delete cascade,
    title text not null,
    description text,
    price_won integer not null default 0,
    book_ids text[] not null default '{}',
    status text not null default 'listed', -- listed/reserved/sold/hidden
    created_at timestamptz default now()
);
create index if not exists bundles_owner_idx on sale_bundles(owner_id);
create index if not exists bundles_status_idx on sale_bundles(status);

-- ============ discussions ============
create table if not exists discussions (
    id text primary key,
    host_id uuid references auth.users(id) on delete cascade,
    book_id text references books(id),
    title text not null,
    description text,
    region text,                     -- "서울 강남구" 형태
    is_online boolean default false,
    scheduled_at timestamptz not null,
    max_participants integer default 10,
    current_participants integer default 1,
    created_at timestamptz default now()
);
create index if not exists discussions_region_idx on discussions(region);
create index if not exists discussions_book_idx on discussions(book_id);
create index if not exists discussions_online_idx on discussions(is_online);

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

-- ============ Row Level Security ============
alter table books enable row level security;
alter table sale_bundles enable row level security;
alter table discussions enable row level security;
alter table reviews enable row level security;

-- 본인 소유 데이터만 읽기/쓰기
create policy "books_owner" on books
    for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

create policy "bundles_owner" on sale_bundles
    for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

-- 토론은 누구나 검색 가능, 작성/수정은 호스트만
create policy "discussions_read" on discussions for select using (true);
create policy "discussions_write" on discussions
    for insert with check (auth.uid() = host_id);
create policy "discussions_update" on discussions
    for update using (auth.uid() = host_id);

-- 리뷰는 누구나 읽기, 작성은 본인만
create policy "reviews_read" on reviews for select using (true);
create policy "reviews_write" on reviews
    for insert with check (auth.uid() = user_id);
