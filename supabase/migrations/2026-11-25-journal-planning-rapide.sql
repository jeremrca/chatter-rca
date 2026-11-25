-- 2026-11-25 · Journal des modifications du planning, version rapide (remplace 2026-11-25-journal-planning.sql)
-- Exécuté le 2026-11-25 avec l'accord du propriétaire.
-- Même journal que la première version (qui, quand, quelles cases, avant / après, autres parties ; 60 jours ;
-- lecture administrateurs et Direction), mais le calcul parcourt les semaines puis les cases une seule fois :
-- ~0,06 s au lieu de ~14 s (mesuré sur le planning de production, sans rien écrire).
-- Sécurité : si le journal rencontre un problème, l'enregistrement du planning passe quand même.
-- Inchangé : app_state, ses droits, le garde-fou app_state_garde_parties, la table planning_journal (déjà créée).
-- Idempotent : « create or replace », « drop … if exists ».

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

    -- Cases modifiées : seules les semaines qui ont changé sont ouvertes, chaque case n'est lue qu'une fois
    select coalesce(jsonb_agg(jsonb_build_object('semaine', wk.w, 'case', cc.c, 'avant', cc.ov, 'apres', cc.nv) order by wk.w, cc.c), '[]'::jsonb)
      into ch
    from (select coalesce(ow.key, nw.key) as w, ow.value as oc, nw.value as nc
          from jsonb_each(case when jsonb_typeof(old.data -> 'weeks') = 'object' then old.data -> 'weeks' else '{}'::jsonb end) ow
          full join jsonb_each(case when jsonb_typeof(new.data -> 'weeks') = 'object' then new.data -> 'weeks' else '{}'::jsonb end) nw on ow.key = nw.key
          where ow.value is distinct from nw.value) wk,
    lateral (select coalesce(o.key, n.key) as c, o.value as ov, n.value as nv
             from jsonb_each(case when jsonb_typeof(wk.oc -> 'cells') = 'object' then wk.oc -> 'cells' else '{}'::jsonb end) o
             full join jsonb_each(case when jsonb_typeof(wk.nc -> 'cells') = 'object' then wk.nc -> 'cells' else '{}'::jsonb end) n on o.key = n.key
             where o.value is distinct from n.value) cc;

    -- Autres parties du planning modifiées
    select coalesce(array_agg(coalesce(o.key, n.key) order by coalesce(o.key, n.key)), '{}')
      into au
    from jsonb_each(old.data) o
    full join jsonb_each(new.data) n on o.key = n.key
    where coalesce(o.key, n.key) not in ('weeks', '_app') and o.value is distinct from n.value;

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
