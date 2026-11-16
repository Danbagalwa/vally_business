-- ════════════════════════════════════════════════════════════════════
--  Vally Business — 5/6 : sécurité (Row Level Security et droits)
--
--  Règle : un compte connecté ne voit et ne modifie que les données de
--  SA boutique (boutique_id = private.ma_boutique()). Le rôle anon
--  (non connecté) n'a accès à rien.
-- ════════════════════════════════════════════════════════════════════

-- ─── Droits de base ─────────────────────────────────────────────────

revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from public, anon;
revoke all on all functions in schema private from public, anon;

-- private n'est pas exposé par l'API ; authenticated doit seulement pouvoir
-- évaluer ma_boutique() dans les règles RLS et les valeurs par défaut.
grant usage on schema private to authenticated;
grant execute on function private.ma_boutique() to authenticated;
-- Appelée par les déclencheurs (qui s'exécutent avec les droits du compte).
grant execute on function private.quantite_vendue(uuid, uuid, uuid) to authenticated;

grant execute on function
  public.creer_boutique(text, text, numeric),
  public.ajouter_membre(text),
  public.retirer_membre(uuid),
  public.membres_boutique(),
  public.verser_benefice(numeric, text, date, text),
  public.dashboard_periode(date, date),
  public.articles_vendus_periode(date, date)
to authenticated;

-- Les fonctions créées plus tard ne seront pas ouvertes à tous par défaut.
alter default privileges in schema public revoke execute on functions from public, anon;

-- ─── RLS activée partout ────────────────────────────────────────────

alter table public.boutiques       enable row level security;
alter table public.membres         enable row level security;
alter table public.articles        enable row level security;
alter table public.clients         enable row level security;
alter table public.commandes       enable row level security;
alter table public.lignes_commande enable row level security;
alter table public.paiements       enable row level security;
alter table public.mouvements      enable row level security;

-- ─── Boutiques : lecture et modification (nom, taux) ────────────────
-- Création : fonction creer_boutique(). Pas de suppression depuis l'appli.

create policy boutiques_select on public.boutiques
  for select to authenticated
  using (id = (select private.ma_boutique()));

create policy boutiques_update on public.boutiques
  for update to authenticated
  using (id = (select private.ma_boutique()))
  with check (id = (select private.ma_boutique()));

-- ─── Membres : lecture seule (ajout / retrait par fonctions) ────────

create policy membres_select on public.membres
  for select to authenticated
  using (boutique_id = (select private.ma_boutique()));

-- ─── Tables métier : tout, mais seulement dans sa boutique ──────────

do $$
declare
  t text;
begin
  foreach t in array array['articles', 'clients', 'commandes', 'lignes_commande', 'paiements']
  loop
    execute format($f$
      create policy %1$s_select on public.%1$I
        for select to authenticated
        using (boutique_id = (select private.ma_boutique()));

      create policy %1$s_insert on public.%1$I
        for insert to authenticated
        with check (boutique_id = (select private.ma_boutique())
                    and user_id = (select auth.uid()));

      create policy %1$s_update on public.%1$I
        for update to authenticated
        using (boutique_id = (select private.ma_boutique()))
        with check (boutique_id = (select private.ma_boutique()));

      create policy %1$s_delete on public.%1$I
        for delete to authenticated
        using (boutique_id = (select private.ma_boutique()));
    $f$, t);
  end loop;
end;
$$;

-- ─── Mouvements : l'appli ne crée que des mouvements « manuel » ─────
-- Les entrées « boutique » viennent uniquement de verser_benefice().
-- Un versement peut être supprimé (il redevient disponible), pas modifié.

create policy mouvements_select on public.mouvements
  for select to authenticated
  using (boutique_id = (select private.ma_boutique()));

create policy mouvements_insert on public.mouvements
  for insert to authenticated
  with check (boutique_id = (select private.ma_boutique())
              and user_id = (select auth.uid())
              and source = 'manuel');

create policy mouvements_update on public.mouvements
  for update to authenticated
  using (boutique_id = (select private.ma_boutique()) and source = 'manuel')
  with check (boutique_id = (select private.ma_boutique()) and source = 'manuel');

create policy mouvements_delete on public.mouvements
  for delete to authenticated
  using (boutique_id = (select private.ma_boutique()));
