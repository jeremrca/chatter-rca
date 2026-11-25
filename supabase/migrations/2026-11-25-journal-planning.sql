-- 2026-11-25 · Journal des modifications du planning (demande du propriétaire)
-- Exécuté le 2026-11-25 avec l'accord du propriétaire.
-- Avant : la base ne gardait que la dernière version du planning ; une case écrasée était perdue sans trace.
-- Après : à chaque enregistrement du planning, la base note qui a modifié quelles cases, à quelle heure,
--         avec le contenu avant et après. Gardé 60 jours.
-- Lecture : administrateurs et Direction seulement. Personne ne peut écrire ni effacer dans le journal depuis le site.
-- Sécurité : si le journal rencontre un problème, l'enregistrement du planning passe quand même (rien n'est bloqué).
-- Inchangé : app_state, ses droits et le garde-fou app_state_garde_parties. Aucune donnée existante modifiée.
-- Idempotent : « if not exists », « create or replace », « drop … if exists ».

create table if not exists public.planning_journal (
  id      bigserial primary key,
  at      timestamptz not null default now(),
  version int,
  par     text,
  cases   jsonb not null default '[]'::jsonb,   -- [{semaine, case, avant, apres}]
  autres  text[] not null default '{}'          -- autres parties modifiées (absences demandées, base chatters, superviseurs…)
);
create index if not exists planning_journal_at on public.planning_journal (at desc);

alter table public.planning_journal enable row level security;
drop policy if exists "journal lecture direction" on public.planning_journal;
create policy "journal lecture direction" on public.planning_journal
  for select to authenticated using (public.is_admin() or public.is_direction());

create or replace function public.planning_journal_noter()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  ch jsonb;
  au text[];
begin
  begin
    if jsonb_typeof(old.data) <> 'object' or jsonb_typeof(new.data) <> 'object' or new.data = old.data then
      return null;
    end if;

    -- Cases du planning qui ont changé (toutes semaines confondues)
    select coalesce(jsonb_agg(jsonb_build_object('semaine', w, 'case', c, 'avant', o, 'apres', n) order by w, c), '[]'::jsonb)
      into ch
    from (
      select ws.w, cs.c,
             old.data -> 'weeks' -> ws.w -> 'cells' -> cs.c as o,
             new.data -> 'weeks' -> ws.w -> 'cells' -> cs.c as n
      from (select jsonb_object_keys(coalesce(old.data -> 'weeks', '{}'::jsonb)) as w
            union select jsonb_object_keys(coalesce(new.data -> 'weeks', '{}'::jsonb))) ws,
      lateral (select jsonb_object_keys(case when jsonb_typeof(old.data -> 'weeks' -> ws.w -> 'cells') = 'object' then old.data -> 'weeks' -> ws.w -> 'cells' else '{}'::jsonb end) as c
               union select jsonb_object_keys(case when jsonb_typeof(new.data -> 'weeks' -> ws.w -> 'cells') = 'object' then new.data -> 'weeks' -> ws.w -> 'cells' else '{}'::jsonb end)) cs
    ) d
    where o is distinct from n;

    -- Autres parties du planning qui ont changé
    select coalesce(array_agg(k order by k), '{}') into au
    from (select jsonb_object_keys(old.data) as k union select jsonb_object_keys(new.data)) t
    where k not in ('weeks', '_app') and old.data -> k is distinct from new.data -> k;

    if ch = '[]'::jsonb and au = '{}' then
      return null;
    end if;

    insert into public.planning_journal (version, par, cases, autres)
    values (new.version, coalesce(auth.jwt() ->> 'email', new.updated_by), ch, au);

    delete from public.planning_journal where at < now() - interval '60 days';
  exception when others then
    null;   -- le journal ne doit jamais empêcher d'enregistrer le planning
  end;
  return null;
end
$function$;

drop trigger if exists planning_journal on public.app_state;
create trigger planning_journal
  after update on public.app_state
  for each row when (new.key = 'planning')
  execute function public.planning_journal_noter();

-- Retiré le 2026-11-25 (5 minutes après, avec l'accord du propriétaire) : le calcul prenait ~14 s par enregistrement,
-- au-delà de la limite de temps des comptes du site (risque de bloquer les enregistrements du planning).
-- Aucun enregistrement du planning n'a eu lieu pendant ces 5 minutes. La table planning_journal (vide) est restée.
-- Remplacé par 2026-11-25-journal-planning-rapide.sql.
-- drop trigger if exists planning_journal on public.app_state;   -- exécuté
