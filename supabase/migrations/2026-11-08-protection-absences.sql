-- 2026-11-08 · Demandes d'absence effacées par d'anciens onglets du site
-- Exécuté le 2026-11-08 avec l'accord du propriétaire (sauvegarde : backups/app_state-2026-11-08.json).

-- Protection : quand un ancien onglet du site enregistre le planning (ou les lancements / mises en avant)
-- sans une partie qu'il ne connaît pas (ex. « absreq » = demandes d'absence), la base garde cette partie
-- au lieu de l'effacer. Les suppressions faites depuis le site à jour ne sont pas concernées
-- (le site à jour envoie toujours chaque partie, même vide).
create or replace function public.app_state_garde_parties() returns trigger
language plpgsql as $$
begin
  if new.key in ('planning', 'plancfg') and jsonb_typeof(old.data) = 'object' and jsonb_typeof(new.data) = 'object' then
    new.data := coalesce((select jsonb_object_agg(k, v) from jsonb_each(old.data) as e(k, v) where not (new.data ? k)), '{}'::jsonb) || new.data;
  end if;
  return new;
end $$;

drop trigger if exists app_state_garde_parties on public.app_state;
create trigger app_state_garde_parties before update on public.app_state
  for each row execute function public.app_state_garde_parties();

-- Remise en place des 10 demandes perdues : exécutée à part le 2026-11-08 (version 3977) (données personnelles, pas dans ce dépôt public).
-- Principe : data->'absreq' := demandes connues au 06/11 22h39 || demandes actuelles (les actuelles gardent la priorité),
-- version + 1 pour que tous les navigateurs la reçoivent.
