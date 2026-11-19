-- 2026-11-19 · Liste du suivi français effacée par un ancien onglet du site
-- Exécuté le 2026-11-19 avec l'accord du propriétaire (sauvegarde : backups/app_state-2026-11-19.json).
--
-- 1. Le garde-fou du 2026-11-08 (planning) est étendu au suivi des chatters (coaching), aux primes et pénalités (suivi)
--    et aux cams / customs (cams) : une partie qu'un ancien onglet ne connaît pas n'est plus jamais effacée.
-- 2. La liste du suivi français (coaching -> fr) ne peut être modifiée que par un administrateur ou la Direction.
--    Pour tout autre compte, la base garde la liste telle qu'elle était.
create or replace function public.app_state_garde_parties() returns trigger
language plpgsql as $$
begin
  if new.key in ('planning', 'plancfg', 'coaching', 'suivi', 'cams') and jsonb_typeof(old.data) = 'object' and jsonb_typeof(new.data) = 'object' then
    new.data := coalesce((select jsonb_object_agg(k, v) from jsonb_each(old.data) as e(k, v) where not (new.data ? k)), '{}'::jsonb) || new.data;
  end if;
  if new.key = 'coaching' and jsonb_typeof(old.data) = 'object' and old.data ? 'fr'
     and not (public.is_admin() or public.is_direction()) then
    new.data := jsonb_set(new.data, '{fr}', old.data -> 'fr');
  end if;
  return new;
end $$;

drop trigger if exists app_state_garde_parties on public.app_state;
create trigger app_state_garde_parties before update on public.app_state
  for each row execute function public.app_state_garde_parties();
