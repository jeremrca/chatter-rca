-- 2026-11-25 · Planning personnel (« Mon planning », d'abord pour Billy) — demande du propriétaire
-- Exécuté le 2026-11-25 avec l'accord du propriétaire (accès ajoutés pour Billy, Jérémy et Clément).
-- Avant : rien.
-- Après : deux nouvelles tables, séparées du reste du site (app_state n'est pas touchée).
--   perso_planning_acces : qui a accès à quel planning personnel (une ligne par personne autorisée).
--   perso_planning       : le contenu (tâches, tâches récurrentes, cases cochées, notes), une ligne par élément.
-- Droits : un compte ne voit et ne modifie un planning personnel que s'il figure dans perso_planning_acces
--          pour ce planning. Personne d'autre (superviseurs, reste de la Direction) ne peut le lire, même hors du site.
--          La liste des accès ne se modifie qu'en SQL (aucune écriture possible depuis le site).
-- Les adresses e-mail des personnes autorisées sont ajoutées par un second script, non commité (dépôt public) :
--   insert into public.perso_planning_acces (owner, email, role, nom) values ('billy', '<e-mail de Billy>', 'proprio', 'Billy'), …
--   on conflict do nothing;
-- Idempotent : « if not exists », « create or replace », « drop … if exists ».

create table if not exists public.perso_planning_acces (
  owner text not null,
  email text not null,
  role  text not null default 'lecteur' check (role in ('proprio', 'lecteur')),
  nom   text,                                  -- prénom affiché (« ajoutée par Clément »)
  primary key (owner, email)
);
alter table public.perso_planning_acces enable row level security;
drop policy if exists "acces lecture soi" on public.perso_planning_acces;
create policy "acces lecture soi" on public.perso_planning_acces
  for select to authenticated using (lower(email) = lower(auth.jwt() ->> 'email'));

create table if not exists public.perso_planning (
  owner      text not null,
  k          text not null,                    -- task:…, rec:…, done:AAAA-MM-JJ:…, skip:…, note:AAAA-MM-JJ, wnote:AAAA-MM-JJ, meta:…
  v          jsonb not null default '{}'::jsonb,
  updated_by text,
  updated_at timestamptz not null default now(),
  primary key (owner, k)
);
alter table public.perso_planning enable row level security;
drop policy if exists "perso planning acces" on public.perso_planning;
create policy "perso planning acces" on public.perso_planning
  for all to authenticated
  using (exists (select 1 from public.perso_planning_acces a where a.owner = perso_planning.owner and lower(a.email) = lower(auth.jwt() ->> 'email')))
  with check (exists (select 1 from public.perso_planning_acces a where a.owner = perso_planning.owner and lower(a.email) = lower(auth.jwt() ->> 'email')));

-- Qui a modifié en dernier, et quand (rempli par la base, pas par le site)
create or replace function public.perso_planning_signe()
returns trigger
language plpgsql
as $function$
begin
  new.updated_by := coalesce(auth.jwt() ->> 'email', new.updated_by);
  new.updated_at := now();
  return new;
end $function$;
drop trigger if exists perso_planning_signe on public.perso_planning;
create trigger perso_planning_signe before insert or update on public.perso_planning
  for each row execute function public.perso_planning_signe();
