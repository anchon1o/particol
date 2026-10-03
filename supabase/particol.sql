-- =====================================================================
--  Particol · base de datos en el proyecto de Supabase "cousas"
--  Todas las tablas llevan el prefijo pc_ para convivir con impro y Forxa.
--  Se puede ejecutar más de una vez sin romper nada.
-- =====================================================================

create extension if not exists pgcrypto;

-- Partituras: el contenido completo (.noa) va en "data"
create table if not exists public.pc_scores (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title       text not null default 'Sin título',
  data        jsonb not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid()
);

-- Personas con acceso a una partitura (además de la dueña)
create table if not exists public.pc_members (
  score_id  uuid not null references public.pc_scores(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      text not null check (role in ('editor','viewer')),
  primary key (score_id, user_id)
);

-- Enlaces para compartir (edición o solo lectura)
create table if not exists public.pc_links (
  token       text primary key default encode(gen_random_bytes(12), 'hex'),
  score_id    uuid not null references public.pc_scores(id) on delete cascade,
  role        text not null check (role in ('editor','viewer')),
  created_at  timestamptz not null default now()
);

-- Historial de versiones con nombre
create table if not exists public.pc_versions (
  id          bigint generated always as identity primary key,
  score_id    uuid not null references public.pc_scores(id) on delete cascade,
  name        text not null,
  data        jsonb not null,
  created_by  uuid default auth.uid(),
  created_at  timestamptz not null default now()
);

create index if not exists pc_scores_owner_idx   on public.pc_scores(owner);
create index if not exists pc_members_user_idx   on public.pc_members(user_id);
create index if not exists pc_versions_score_idx on public.pc_versions(score_id, created_at desc);

-- Rol de la persona conectada en una partitura: 'owner', 'editor', 'viewer' o nulo
create or replace function public.pc_role(sid uuid) returns text
language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from pc_scores s where s.id = sid and s.owner = auth.uid()) then 'owner'
    else (select m.role from pc_members m where m.score_id = sid and m.user_id = auth.uid())
  end
$$;

-- Unirse a una partitura con un enlace compartido
create or replace function public.pc_join(tok text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l pc_links;
begin
  if auth.uid() is null then raise exception 'Hay que iniciar sesión'; end if;
  select * into l from pc_links where token = tok;
  if not found then raise exception 'Enlace no válido o caducado'; end if;
  if pc_role(l.score_id) is null then
    insert into pc_members(score_id, user_id, role) values (l.score_id, auth.uid(), l.role)
    on conflict (score_id, user_id) do nothing;
  end if;
  return l.score_id;
end $$;

-- Fecha y autor de la última modificación
create or replace function public.pc_touch() returns trigger
language plpgsql as $$
begin new.updated_at = now(); new.updated_by = auth.uid(); return new; end $$;

drop trigger if exists pc_scores_touch on public.pc_scores;
create trigger pc_scores_touch before update on public.pc_scores
  for each row execute function public.pc_touch();

-- Seguridad: cada persona solo ve y toca lo suyo o lo compartido con ella
alter table public.pc_scores   enable row level security;
alter table public.pc_members  enable row level security;
alter table public.pc_links    enable row level security;
alter table public.pc_versions enable row level security;

drop policy if exists "pc_scores leer"    on public.pc_scores;
drop policy if exists "pc_scores crear"   on public.pc_scores;
drop policy if exists "pc_scores editar"  on public.pc_scores;
drop policy if exists "pc_scores borrar"  on public.pc_scores;
create policy "pc_scores leer"   on public.pc_scores for select using (pc_role(id) is not null);
create policy "pc_scores crear"  on public.pc_scores for insert with check (owner = auth.uid());
create policy "pc_scores editar" on public.pc_scores for update using (pc_role(id) in ('owner','editor'));
create policy "pc_scores borrar" on public.pc_scores for delete using (owner = auth.uid());

drop policy if exists "pc_members leer"      on public.pc_members;
drop policy if exists "pc_members gestionar" on public.pc_members;
drop policy if exists "pc_members salir"     on public.pc_members;
create policy "pc_members leer"      on public.pc_members for select using (pc_role(score_id) is not null);
create policy "pc_members gestionar" on public.pc_members for all
  using (pc_role(score_id) = 'owner') with check (pc_role(score_id) = 'owner');
create policy "pc_members salir"     on public.pc_members for delete using (user_id = auth.uid());

drop policy if exists "pc_links dueña" on public.pc_links;
create policy "pc_links dueña" on public.pc_links for all
  using (pc_role(score_id) = 'owner') with check (pc_role(score_id) = 'owner');

drop policy if exists "pc_versions leer"   on public.pc_versions;
drop policy if exists "pc_versions crear"  on public.pc_versions;
drop policy if exists "pc_versions borrar" on public.pc_versions;
create policy "pc_versions leer"   on public.pc_versions for select using (pc_role(score_id) is not null);
create policy "pc_versions crear"  on public.pc_versions for insert with check (pc_role(score_id) in ('owner','editor'));
create policy "pc_versions borrar" on public.pc_versions for delete using (pc_role(score_id) = 'owner');

grant execute on function public.pc_role(uuid) to authenticated;
grant execute on function public.pc_join(text) to authenticated;

-- =====================================================================
--  Límites para convivir con otros proyectos en la misma base de datos
--  (solo texto JSON: nada de audio ni archivos pesados)
-- =====================================================================
alter table public.pc_scores   drop constraint if exists pc_scores_peso;
alter table public.pc_scores   add  constraint pc_scores_peso   check (octet_length(data::text) <= 1000000);
alter table public.pc_versions drop constraint if exists pc_versions_peso;
alter table public.pc_versions add  constraint pc_versions_peso check (octet_length(data::text) <= 1000000);

-- Se conservan solo las 20 versiones más recientes de cada partitura
create or replace function public.pc_cap_versions() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from pc_versions where score_id = new.score_id
    and id not in (select id from pc_versions where score_id = new.score_id order by created_at desc limit 20);
  return null;
end $$;
drop trigger if exists pc_versions_cap on public.pc_versions;
create trigger pc_versions_cap after insert on public.pc_versions for each row execute function public.pc_cap_versions();

-- Máximo de 200 partituras por persona
create or replace function public.pc_cap_scores() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from pc_scores where owner = auth.uid()) >= 200 then
    raise exception 'Has llegado al máximo de 200 partituras en la nube';
  end if;
  return new;
end $$;
drop trigger if exists pc_scores_cap on public.pc_scores;
create trigger pc_scores_cap before insert on public.pc_scores for each row execute function public.pc_cap_scores();
