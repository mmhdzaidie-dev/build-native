create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'ZEIA User',
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.songs (
  id text primary key,
  title text not null,
  artist text not null default '',
  cover text not null default '',
  duration text not null default '',
  album text not null default '',
  album_id text not null default '',
  artist_id text not null default '',
  yt_url text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.playlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  cover_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.playlist_songs (
  playlist_id uuid not null references public.playlists(id) on delete cascade,
  song_id text not null references public.songs(id) on delete cascade,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (playlist_id, song_id)
);

create table if not exists public.liked_songs (
  user_id uuid not null references public.profiles(id) on delete cascade,
  song_id text not null references public.songs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, song_id)
);

create table if not exists public.recently_played (
  user_id uuid not null references public.profiles(id) on delete cascade,
  song_id text not null references public.songs(id) on delete cascade,
  played_at timestamptz not null default now(),
  primary key (user_id, song_id)
);

create index if not exists profiles_display_name_idx on public.profiles(display_name);
create index if not exists playlist_songs_playlist_position_idx on public.playlist_songs(playlist_id, position);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(coalesce(new.email, 'ZEIA User'), '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.songs enable row level security;
alter table public.playlists enable row level security;
alter table public.playlist_songs enable row level security;
alter table public.liked_songs enable row level security;
alter table public.recently_played enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated using (true);
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists songs_select on public.songs;
create policy songs_select on public.songs for select to authenticated using (true);
drop policy if exists songs_insert on public.songs;
create policy songs_insert on public.songs for insert to authenticated with check (true);
drop policy if exists songs_update on public.songs;
create policy songs_update on public.songs for update to authenticated using (true) with check (true);

drop policy if exists playlists_select on public.playlists;
create policy playlists_select on public.playlists for select to authenticated using (user_id = auth.uid());
drop policy if exists playlists_insert on public.playlists;
create policy playlists_insert on public.playlists for insert to authenticated with check (user_id = auth.uid());
drop policy if exists playlists_update on public.playlists;
create policy playlists_update on public.playlists for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists playlists_delete on public.playlists;
create policy playlists_delete on public.playlists for delete to authenticated using (user_id = auth.uid());

drop policy if exists playlist_songs_select on public.playlist_songs;
create policy playlist_songs_select on public.playlist_songs for select to authenticated using (exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = auth.uid()));
drop policy if exists playlist_songs_insert on public.playlist_songs;
create policy playlist_songs_insert on public.playlist_songs for insert to authenticated with check (exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = auth.uid()));
drop policy if exists playlist_songs_update on public.playlist_songs;
create policy playlist_songs_update on public.playlist_songs for update to authenticated using (exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = auth.uid())) with check (exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = auth.uid()));
drop policy if exists playlist_songs_delete on public.playlist_songs;
create policy playlist_songs_delete on public.playlist_songs for delete to authenticated using (exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = auth.uid()));

drop policy if exists liked_select on public.liked_songs;
create policy liked_select on public.liked_songs for select to authenticated using (user_id = auth.uid());
drop policy if exists liked_insert on public.liked_songs;
create policy liked_insert on public.liked_songs for insert to authenticated with check (user_id = auth.uid());
drop policy if exists liked_delete on public.liked_songs;
create policy liked_delete on public.liked_songs for delete to authenticated using (user_id = auth.uid());

drop policy if exists recent_select on public.recently_played;
create policy recent_select on public.recently_played for select to authenticated using (user_id = auth.uid());
drop policy if exists recent_insert on public.recently_played;
create policy recent_insert on public.recently_played for insert to authenticated with check (user_id = auth.uid());
drop policy if exists recent_update on public.recently_played;
create policy recent_update on public.recently_played for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());


insert into storage.buckets (id, name, public) values ('playlist-covers', 'playlist-covers', true) on conflict (id) do update set public = true;
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do update set public = true;

drop policy if exists playlist_covers_public_read on storage.objects;
create policy playlist_covers_public_read on storage.objects for select using (bucket_id = 'playlist-covers');
drop policy if exists playlist_covers_owner_insert on storage.objects;
create policy playlist_covers_owner_insert on storage.objects for insert to authenticated with check (bucket_id = 'playlist-covers' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists playlist_covers_owner_update on storage.objects;
create policy playlist_covers_owner_update on storage.objects for update to authenticated using (bucket_id = 'playlist-covers' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'playlist-covers' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists playlist_covers_owner_delete on storage.objects;
create policy playlist_covers_owner_delete on storage.objects for delete to authenticated using (bucket_id = 'playlist-covers' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_public_read on storage.objects;
create policy avatars_public_read on storage.objects for select using (bucket_id = 'avatars');
drop policy if exists avatars_owner_insert on storage.objects;
create policy avatars_owner_insert on storage.objects for insert to authenticated with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists avatars_owner_update on storage.objects;
create policy avatars_owner_update on storage.objects for update to authenticated using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists avatars_owner_delete on storage.objects;
create policy avatars_owner_delete on storage.objects for delete to authenticated using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

alter table public.profiles replica identity full;
alter table public.playlists replica identity full;
alter table public.playlist_songs replica identity full;
alter table public.liked_songs replica identity full;
alter table public.recently_played replica identity full;

do $$
declare
  t text;
begin
  foreach t in array array['profiles','playlists','playlist_songs','liked_songs','recently_played'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
