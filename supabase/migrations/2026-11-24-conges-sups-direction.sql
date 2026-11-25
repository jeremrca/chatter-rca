-- 2026-11-24 · Congés des superviseurs réservés à la Direction (demande du propriétaire)
-- Exécuté le 2026-11-25 avec l'accord du propriétaire.
-- Avant : dans le planning, seul le site empêchait un superviseur de modifier les congés des superviseurs (planning.supConges).
-- Après : la base l'empêche aussi. Si un compte qui n'est ni administrateur ni Direction enregistre le planning,
--         la partie supConges reste celle qui était en base (ses autres modifications du planning passent normalement).
-- Inchangé : la protection des parties (planning, coaching, suivi, cams) et la liste du suivi français (coaching.fr).
-- Idempotent : « create or replace » de la fonction déjà branchée sur app_state ; aucune donnée modifiée.
create or replace function public.app_state_garde_parties()
returns trigger
language plpgsql
as $function$
begin
  if new.key in ('planning', 'plancfg', 'coaching', 'suivi', 'cams') and jsonb_typeof(old.data) = 'object' and jsonb_typeof(new.data) = 'object' then
    new.data := coalesce((select jsonb_object_agg(k, v) from jsonb_each(old.data) as e(k, v) where not (new.data ? k)), '{}'::jsonb) || new.data;
  end if;
  if new.key = 'coaching' and jsonb_typeof(old.data) = 'object' and old.data ? 'fr'
     and not (public.is_admin() or public.is_direction()) then
    new.data := jsonb_set(new.data, '{fr}', old.data -> 'fr');
  end if;
  -- Congés des superviseurs : seulement les administrateurs et la Direction
  if new.key = 'planning' and jsonb_typeof(old.data) = 'object' and jsonb_typeof(new.data) = 'object'
     and not (public.is_admin() or public.is_direction()) then
    if old.data ? 'supConges' then
      new.data := jsonb_set(new.data, '{supConges}', old.data -> 'supConges');
    else
      new.data := new.data - 'supConges';
    end if;
  end if;
  return new;
end $function$;
