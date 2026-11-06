# Chatter RCA Grading — guide pour Claude Code

Site interne de **Redes Content Agency** (agence OFM) : notation des chatters OnlyFans / MYM, ASV, planning,
primes & pénalités, cams / customs, suivi des chatters faibles. Utilisé chaque jour par le propriétaire,
la Direction et une dizaine de superviseurs. **C'est un outil de production : prudence avant chaque changement.**

## Où est quoi

- **Tout le site tient dans un seul fichier : `index.html`** (HTML + CSS + JavaScript, pas de build, pas de dépendances à installer).
  - `<script id="engine">` : moteur de calcul (`RCA` : plateformes OF/MYM, KPI, scoring, imports, `RCA.ASV`, auto-tests).
  - Le second `<script>` est une seule fonction `(() => { ... })();` qui contient toute l'interface : routing par hash (`#of/dashboard`, `#of/planning`, `#of/coaching`…), rendu des pages, module `Sync` (Supabase).
  - Bibliothèques chargées depuis jsDelivr (versions figées) : Chart.js 4.4.1, SheetJS xlsx 0.18.5.
- **Hébergement : GitHub Pages**, branche `main`, fichier `index.html` à la racine. Un `git push` sur `main` met le site en ligne en 1 à 2 minutes.
- **Configuration Supabase** (publique, normale dans le fichier) : `const SHARED_CONFIG = {url: 'https://cflxwuiekkoegubjbiow.supabase.co', anonKey: 'sb_publishable_…'}`.

## Données (Supabase)

- Table `public.app_state (key text primary key, data jsonb, version int, updated_by text, …)` : une ligne par bloc partagé.
  Clés : `periods`, `settings`, `asv`, `asvcfg`, `planning`, `plancfg`, `suivi`, `cams`, `coaching`.
  - Écriture optimiste : `PATCH … ?key=eq.X&version=eq.N` avec `version: N+1`. Réponse vide = conflit → fusion à 3 voies (`deepMerge`) puis nouvel essai.
  - Ajouter une nouvelle clé = l'ajouter dans `KEYS`, `OPTIONAL`, `EMPTY`, `getData`, `setData`, `hasLocal`, `remoteEmpty`, `merge` du module `Sync`, **et** insérer la ligne en SQL (`insert into public.app_state (key, data) values ('X', '{}'::jsonb) on conflict (key) do nothing;`).
  - `setData` met à jour les objets **en place** (`syncInPlace`) : ne jamais réassigner `planState`, `suiviState`, `camsState`, `coachState`.
- Temps réel : publication `supabase_realtime` sur `app_state` ; le site écoute en WebSocket et se met à jour sans recharger (indicateur « Partagé · en direct »).
- Rôles :
  - `public.admins (email)` + fonction `public.is_admin()` : peuvent modifier les paramètres (clés protégées `settings`, `asvcfg`, `plancfg`).
  - `public.direction (email)` + fonction `public.is_direction()` : voient tous les chatters suivis et toutes les notes.
  - Les autres comptes (superviseurs) : lecture de tout, écriture sur les clés non protégées.
- Notes de suivi : table `public.coach_notes` protégée par RLS (lecture : auteur ou Direction ; ajout : auteur ; suppression : auteur ou admin).

## Règles à suivre pour toute modification

1. **Langue** : toute l'interface est en **français** (vouvoiement côté propriétaire, tutoiement jamais dans l'UI). Apostrophes et guillemets typographiques dans les textes affichés (’ « »), apostrophes droites dans le code.
2. **Garder le style existant** : thème sombre Redes, variables CSS existantes, classes existantes (`panel`, `btn`, `pill`, `qpt`, `ptopt`…). Ne pas introduire de framework.
3. **Ne rien casser** : après chaque modification, ouvrir le site en local et parcourir toutes les pages (`#of/dashboard`, `#of/chatters`, `#of/import`, `#mym/dashboard`, `#mym/import`, `#of/asv`, `#of/planning`, `#of/suivi`, `#of/cams`, `#of/coaching`, `#of/partage`) : aucune erreur en console, « Auto-test : 20/20 réussis » en bas du menu.
   Vérifier la syntaxe JS avant de pousser : extraire les deux blocs `<script>` et lancer `node --check`.
4. **SQL : toujours montrer le script au propriétaire et attendre son accord avant de l'exécuter.**
   - Jamais de `drop table`, `truncate`, `delete` sur `app_state`, ni de modification de RLS qui élargirait les droits, sans demande explicite.
   - Avant toute migration qui touche `app_state` : sauvegarder son contenu (`select key, version, data from public.app_state`) dans `backups/app_state-AAAA-MM-JJ.json` (ce dossier est dans `.gitignore`).
   - Scripts idempotents (`if not exists`, `on conflict do nothing`, `drop policy if exists`).
   - Noter chaque script exécuté dans `supabase/migrations/AAAA-MM-JJ-description.sql` (commité).
5. **Mise en ligne** : `git add index.html supabase/ && git commit -m "…" && git push`. Puis vérifier le site en ligne après 2 minutes.
   Rappeler au propriétaire de prévenir les superviseurs de recharger (Cmd/Ctrl + Maj + R) quand la modification touche le partage ou le planning.
6. **Secrets** : ne jamais commiter de mot de passe, de token Supabase personnel ou de clé `service_role`. Ils restent dans `.env` (ignoré par git) ou dans la configuration du serveur MCP.
7. **À la fin de chaque tâche**, résumer en français, sans jargon : ce qui a changé pour les utilisateurs, ce qui a été testé, le SQL exécuté (s'il y en a), et ce que le propriétaire doit faire (en général : rien, ou prévenir les superviseurs).

## Repères dans le code (rechercher ces noms)

- Notation : `PLATFORMS`, `scoreChatter`, `computePeriod`, `combinePeriods`, `renderDashboard`, `renderImport`.
- ASV : `RCA.ASV`, `renderASV`.
- Planning : `renderPlanning`, `editCell`, `planModelsMap`, `supPlanHTML`, `supAssignHTML`, `absReqHTML`, `planBilanHTML`, `planXlsxParse`.
- Primes & pénalités : `renderSuivi`, `suiviEdit`. Cams / customs : `renderCams`, `camEdit`, `camLevel`.
- Suivi des chatters : `coachBuild`, `coachMatch`, `renderCoaching`, `coachSupView`, `coachDecisionsHTML`.
- Partage : `const Sync = (() => {`, `pull`, `pushKey`, `rtStart`, `refreshRoles`.

## Outils pour Claude (déjà en place sur le Mac du propriétaire)

- **GitHub** : `gh` est connecté au compte `jeremrca` (dépôt public `jeremrca/chatter-rca`, site : https://jeremrca.github.io/chatter-rca/).
- **Supabase** : le CLI `supabase` est connecté. Projet du site : `cflxwuiekkoegubjbiow` (l'autre projet, `redes-compta`, n'a rien à voir).
  - Lecture : `supabase db query --remote=cflxwuiekkoegubjbiow --read-only "select …"`.
  - Écriture : même commande sans `--read-only`, **seulement après accord du propriétaire** (règle 4).
- **Aperçu local sans risque** : `node .claude/apercu.mjs` fabrique `.apercu/index.html` (ignoré par git), une copie du site
  **déconnectée de Supabase** (les essais restent dans le navigateur) et vérifie la syntaxe JS (`node --check`).
  `--donnees` y charge en plus une copie en lecture seule des données de production (à demander au propriétaire).
  Servir avec `python3 -m http.server 8765 --bind 127.0.0.1 --directory .apercu` (configuration « apercu » dans `.claude/launch.json`),
  puis parcourir les pages listées en règle 3.
