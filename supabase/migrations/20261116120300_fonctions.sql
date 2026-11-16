-- ════════════════════════════════════════════════════════════════════
--  Vally Business — 4/6 : fonctions appelées par l'appli (RPC)
--
--  Les fonctions SECURITY DEFINER contournent RLS : chacune vérifie
--  elle-même l'identité (auth.uid()) et l'appartenance à la boutique.
-- ════════════════════════════════════════════════════════════════════

-- Boutique du compte connecté, ou erreur s'il n'en a pas.
create function private.exiger_boutique()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_boutique uuid;
begin
  if (select auth.uid()) is null then
    raise exception using message = 'Connecte-toi pour continuer.', hint = 'non_connecte';
  end if;
  v_boutique := private.ma_boutique();
  if v_boutique is null then
    raise exception using
      message = 'Ton compte n''est rattaché à aucune boutique.',
      hint = 'sans_boutique';
  end if;
  return v_boutique;
end;
$$;

-- Montant à la française pour les messages : « 125 000 » (CDF), « 12,50 » (USD).
create function private.formater_montant(p_montant numeric, p_devise text)
returns text
language sql
immutable
set search_path = ''
as $$
  select replace(replace(
           to_char(p_montant, case when p_devise = 'USD' then 'FM999,999,999,990.00'
                                   else 'FM999,999,999,990' end),
           ',', ' '), '.', ',')
$$;

-- ─── Créer sa boutique (le compte en devient admin) ─────────────────

create function public.creer_boutique(
  p_nom text,
  p_devise_reference text,
  p_taux_usd_cdf numeric
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_boutique uuid;
begin
  if v_uid is null then
    raise exception using message = 'Connecte-toi pour continuer.', hint = 'non_connecte';
  end if;
  if private.ma_boutique() is not null then
    raise exception using
      message = 'Ton compte a déjà une boutique.',
      hint = 'deja_membre';
  end if;

  insert into public.boutiques (user_id, nom, devise_reference, taux_usd_cdf)
  values (v_uid, btrim(p_nom), p_devise_reference, p_taux_usd_cdf)
  returning id into v_boutique;

  insert into public.membres (boutique_id, user_id, role, ajoute_par)
  values (v_boutique, v_uid, 'admin', v_uid);

  return v_boutique;
end;
$$;

-- ─── Membres ────────────────────────────────────────────────────────

-- Ajoute un compte existant (par son email) à la boutique.
create function public.ajouter_membre(p_email text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_boutique uuid := private.exiger_boutique();
  v_cible uuid;
begin
  select u.id into v_cible
  from auth.users u
  where lower(u.email) = lower(btrim(p_email));

  if v_cible is null then
    raise exception using
      message = 'Aucun compte avec cet email. Demande à la personne de créer son compte dans l''appli, puis réessaie.',
      hint = 'compte_introuvable';
  end if;

  if exists (select 1 from public.membres m where m.user_id = v_cible) then
    raise exception using
      message = 'Ce compte fait déjà partie d''une boutique.',
      hint = 'deja_membre';
  end if;

  insert into public.membres (boutique_id, user_id, role, ajoute_par)
  values (v_boutique, v_cible, 'admin', (select auth.uid()));

  return v_cible;
end;
$$;

-- Retire un membre. La boutique garde toujours au moins un membre.
create function public.retirer_membre(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_boutique uuid := private.exiger_boutique();
begin
  -- Verrou : deux retraits simultanés ne peuvent pas vider la boutique.
  perform 1 from public.boutiques b where b.id = v_boutique for update;

  if not exists (
    select 1 from public.membres m
    where m.boutique_id = v_boutique and m.user_id = p_user_id
  ) then
    raise exception using message = 'Ce compte ne fait pas partie de ta boutique.', hint = 'membre_introuvable';
  end if;

  if (select count(*) from public.membres m where m.boutique_id = v_boutique) <= 1 then
    raise exception using
      message = 'Ta boutique doit garder au moins un membre.',
      hint = 'dernier_membre';
  end if;

  delete from public.membres m
  where m.boutique_id = v_boutique and m.user_id = p_user_id;
end;
$$;

-- Liste des membres avec leur email (auth.users n'est pas lisible directement).
create function public.membres_boutique()
returns table (user_id uuid, email text, role text, created_at timestamptz, est_moi boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select m.user_id,
         u.email::text,
         m.role,
         m.created_at,
         m.user_id = (select auth.uid())
  from public.membres m
  join auth.users u on u.id = m.user_id
  where m.boutique_id = private.ma_boutique()
  order by m.created_at
$$;

-- ─── « Me verser un bénéfice » ──────────────────────────────────────
-- Seul moyen de créer une entrée « boutique » dans Mes dépenses.
-- Le montant ne peut pas dépasser le bénéfice disponible.

create function public.verser_benefice(
  p_montant_saisi numeric,
  p_devise_saisie text,
  p_date date default current_date,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_boutique   uuid := private.exiger_boutique();
  v_devise     text;
  v_taux       numeric;
  v_montant    numeric;
  v_disponible numeric;
  v_id         uuid;
begin
  -- Verrou : deux versements simultanés ne peuvent pas dépasser le disponible.
  select b.devise_reference, b.taux_usd_cdf into v_devise, v_taux
  from public.boutiques b
  where b.id = v_boutique
  for update;

  if p_montant_saisi is null or p_montant_saisi <= 0 then
    raise exception using message = 'Saisis un montant supérieur à zéro.', hint = 'montant_invalide';
  end if;

  v_montant := case
    when p_devise_saisie = v_devise then p_montant_saisi
    when p_devise_saisie = 'USD'    then round(p_montant_saisi * v_taux, 2)
    else                                 round(p_montant_saisi / v_taux, 2)
  end;

  select (coalesce((
            select sum(vc.benefice) from public.v_commandes vc
            where vc.boutique_id = v_boutique and vc.statut_livraison <> 'annulee'), 0)
         - coalesce((
            select sum(mv.montant) from public.mouvements mv
            where mv.boutique_id = v_boutique and mv.source = 'boutique'), 0))
    into v_disponible;

  if v_montant > v_disponible then
    raise exception using
      message = format('Bénéfice disponible insuffisant : il reste %s %s.',
                       private.formater_montant(greatest(v_disponible, 0), v_devise), v_devise),
      hint = 'benefice_insuffisant';
  end if;

  insert into public.mouvements
    (boutique_id, user_id, type, montant_saisi, devise_saisie, categorie,
     date_mouvement, note, source)
  values
    (v_boutique, (select auth.uid()), 'entree', p_montant_saisi, p_devise_saisie,
     'Bénéfice boutique', coalesce(p_date, current_date), p_note, 'boutique')
  returning id into v_id;

  return v_id;
end;
$$;

-- ─── Tableau de bord sur une période ────────────────────────────────
-- SECURITY INVOKER : RLS s'applique, seule la boutique du compte est lue.

create function public.dashboard_periode(p_debut date, p_fin date)
returns table (
  total_approvisionne numeric,
  chiffre_affaires    numeric,
  cout_ventes         numeric,
  benefice            numeric,
  total_encaisse      numeric,
  reste_du            numeric,
  gain_au_dessus      numeric,
  cout_remises        numeric,
  nb_commandes        integer,
  pieces_vendues      integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  with v as (
    select coalesce(sum(vc.total), 0)          as chiffre_affaires,
           coalesce(sum(vc.cout), 0)           as cout_ventes,
           coalesce(sum(vc.benefice), 0)       as benefice,
           coalesce(sum(vc.reste_a_payer), 0)  as reste_du,
           coalesce(sum(vc.gain_au_dessus), 0) as gain_au_dessus,
           coalesce(sum(vc.cout_remises), 0)   as cout_remises,
           count(*)::integer                   as nb_commandes,
           coalesce(sum(vc.nb_pieces), 0)::integer as pieces_vendues
    from public.v_commandes vc
    where vc.statut_livraison <> 'annulee'
      and vc.date_commande between p_debut and p_fin
  )
  select
    (select coalesce(sum(a.quantite_achetee * a.prix_achat), 0)
       from public.articles a
      where a.date_appro between p_debut and p_fin),
    v.chiffre_affaires,
    v.cout_ventes,
    v.benefice,
    -- Argent réellement reçu pendant la période (commandes non annulées).
    (select coalesce(sum(p.montant), 0)
       from public.paiements p
       join public.commandes c on c.id = p.commande_id
      where c.statut_livraison <> 'annulee'
        and p.date_paiement between p_debut and p_fin),
    v.reste_du,
    v.gain_au_dessus,
    v.cout_remises,
    v.nb_commandes,
    v.pieces_vendues
  from v
$$;

-- Articles vendus sur une période, du plus vendu au moins vendu.
create function public.articles_vendus_periode(p_debut date, p_fin date)
returns table (
  article_id       uuid,
  nom              text,
  categorie        text,
  taille           text,
  quantite         integer,
  chiffre_affaires numeric,
  benefice         numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  select a.id,
         a.nom,
         a.categorie,
         a.taille,
         sum(l.quantite)::integer,
         sum(l.quantite * l.prix_vendu),
         sum(l.quantite * (l.prix_vendu - l.prix_achat_snapshot))
  from public.lignes_commande l
  join public.commandes c on c.id = l.commande_id
  join public.articles a  on a.id = l.article_id
  where c.statut_livraison <> 'annulee'
    and c.date_commande between p_debut and p_fin
  group by a.id, a.nom, a.categorie, a.taille
  order by sum(l.quantite) desc, a.nom
$$;
