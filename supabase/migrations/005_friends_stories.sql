-- Друзья и истории SVOI

-- Дружбы. Примечание: изменение/удаление разрешено ОБОИМ участникам
-- (иначе получатель заявки не смог бы её принять или отклонить).
create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  unique(user_id, friend_id)
);

alter table public.friendships enable row level security;

create policy "Friendships readable by participants"
  on public.friendships for select
  using (user_id = auth.uid() or friend_id = auth.uid());

create policy "Users can send friend requests"
  on public.friendships for insert
  with check (user_id = auth.uid());

create policy "Participants can update friendships"
  on public.friendships for update
  using (user_id = auth.uid() or friend_id = auth.uid());

create policy "Participants can delete friendships"
  on public.friendships for delete
  using (user_id = auth.uid() or friend_id = auth.uid());

-- Истории
create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_url text not null,
  media_type text not null check (media_type in ('image', 'video')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create index if not exists stories_expires_at_idx on public.stories (expires_at);

alter table public.stories enable row level security;

create policy "Stories are readable by everyone"
  on public.stories for select
  using (true);

create policy "Users can create their own stories"
  on public.stories for insert
  with check (user_id = auth.uid());

create policy "Users can delete their own stories"
  on public.stories for delete
  using (user_id = auth.uid());

-- Публичный bucket для историй
insert into storage.buckets (id, name, public)
values ('stories', 'stories', true)
on conflict (id) do nothing;

create policy "Stories media readable by everyone"
  on storage.objects for select
  using (bucket_id = 'stories');

create policy "Users can upload their own stories media"
  on storage.objects for insert
  with check (
    bucket_id = 'stories'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete their own stories media"
  on storage.objects for delete
  using (
    bucket_id = 'stories'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
