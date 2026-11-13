-- Уведомления, сообщения и редактирование постов SVOI

-- Редактирование постов автором (нужно для функции «Редактировать»)
create policy "Authors can update their posts"
  on public.posts for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Уведомления
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('friend_request', 'friend_accept', 'like', 'comment')),
  post_id uuid references public.posts(id) on delete cascade,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "Users read their own notifications"
  on public.notifications for select
  using (user_id = auth.uid());

create policy "Users update their own notifications"
  on public.notifications for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Создание — при действии: автор действия вставляет уведомление
create policy "Actors can create notifications"
  on public.notifications for insert
  with check (actor_id = auth.uid());

-- Сообщения
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists messages_pair_idx
  on public.messages (sender_id, receiver_id, created_at);

alter table public.messages enable row level security;

create policy "Participants read their messages"
  on public.messages for select
  using (sender_id = auth.uid() or receiver_id = auth.uid());

create policy "Participants send messages"
  on public.messages for insert
  with check (sender_id = auth.uid());

create policy "Receiver marks messages read"
  on public.messages for update
  using (receiver_id = auth.uid())
  with check (receiver_id = auth.uid());

-- Realtime для сообщений
alter publication supabase_realtime add table public.messages;
