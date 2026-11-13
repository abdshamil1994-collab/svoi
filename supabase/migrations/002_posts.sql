-- Лента постов SVOI
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  text text not null check (char_length(text) <= 1000),
  image_url text,
  created_at timestamptz not null default now()
);

alter table public.posts enable row level security;

-- Чтение всем
create policy "Posts are readable by everyone"
  on public.posts for select
  using (true);

-- Создание только авторизованным (от своего имени)
create policy "Authenticated users can create posts"
  on public.posts for insert
  with check (auth.uid() = user_id);

-- Удаление только автором
create policy "Authors can delete their posts"
  on public.posts for delete
  using (auth.uid() = user_id);

-- Публичный bucket для фото постов
insert into storage.buckets (id, name, public)
values ('post-images', 'post-images', true)
on conflict (id) do nothing;

create policy "Post images are readable by everyone"
  on storage.objects for select
  using (bucket_id = 'post-images');

create policy "Users can upload their own post images"
  on storage.objects for insert
  with check (
    bucket_id = 'post-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete their own post images"
  on storage.objects for delete
  using (
    bucket_id = 'post-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
