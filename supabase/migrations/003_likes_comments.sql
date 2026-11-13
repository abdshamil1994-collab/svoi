-- Лайки, комментарии и видео в постах SVOI

-- Видео в постах
alter table public.posts add column if not exists video_url text;

-- Лайки
create table if not exists public.likes (
  post_id uuid not null references public.posts on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.likes enable row level security;

create policy "Likes are readable by everyone"
  on public.likes for select
  using (true);

create policy "Authenticated users can like"
  on public.likes for insert
  with check (auth.uid() = user_id);

create policy "Users can remove their own likes"
  on public.likes for delete
  using (auth.uid() = user_id);

-- Комментарии
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  text text not null check (char_length(text) <= 500),
  created_at timestamptz not null default now()
);

alter table public.comments enable row level security;

create policy "Comments are readable by everyone"
  on public.comments for select
  using (true);

create policy "Authenticated users can comment"
  on public.comments for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own comments"
  on public.comments for delete
  using (auth.uid() = user_id);

-- Публичный bucket для видео постов
insert into storage.buckets (id, name, public)
values ('post-videos', 'post-videos', true)
on conflict (id) do nothing;

create policy "Post videos are readable by everyone"
  on storage.objects for select
  using (bucket_id = 'post-videos');

create policy "Users can upload their own post videos"
  on storage.objects for insert
  with check (
    bucket_id = 'post-videos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete their own post videos"
  on storage.objects for delete
  using (
    bucket_id = 'post-videos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
