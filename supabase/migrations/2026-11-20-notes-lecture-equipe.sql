-- 2026-11-20 · Notes de suivi visibles par toute l'équipe (demande du propriétaire)
-- Exécuté le 2026-11-20 avec l'accord du propriétaire.
-- Avant : une note n'était lisible que par son auteur et la Direction.
-- Après : tout compte connecté au site lit toutes les notes (pour suivre un chatter qui change de superviseur).
-- Inchangé : chacun n'ajoute que des notes à son nom ; suppression par l'auteur ou un administrateur ; aucun accès sans connexion.
drop policy if exists "notes lecture" on public.coach_notes;
create policy "notes lecture" on public.coach_notes for select to authenticated using (true);
