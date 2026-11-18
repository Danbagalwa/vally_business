-- ════════════════════════════════════════════════════════════════════
--  Vally Business — mise à jour du 19/11/2026 : commandes en cours
--
--  Une commande ni payée en entier, ni livrée, n'est plus comptée comme
--  vendue (total vendu, bénéfice, articles vendus, dettes clients).
--
--  À coller dans Supabase : SQL Editor → New query → Run.
--  À exécuter UNE FOIS, après 2026-11-18_mes_depenses.sql.
-- ════════════════════════════════════════════════════════════════════

begin;

-- ════════════════════════════════════════════════════════════════════
--  Vally Business — une commande pas encore payée n'est pas une vente
--
--  Une ligne de v_commandes est « comptée » (vendue) si elle n'est pas
--  annulée ET :
--    • c'est une vente au comptoir (le client est reparti avec), OU
--    • c'est une commande payée en entier, OU
--    • c'est une commande livrée (remise au client : il doit l'argent).
--  Sinon c'est une commande EN COURS : stock réservé, avances encaissées,
--  mais absente du total vendu, du bénéfice, des articles vendus et des
--  dettes clients.
-- ════════════════════════════════════════════════════════════════════

-- ─── v_commandes : nouvelle colonne « comptee » (à la fin) ───────────

create or replace view public.v_commandes
with (security_invoker = true)
as
with lignes as (
  select l.commande_id,
         sum(l.quantite)::integer                                     as nb_pieces,
         sum(l.quantite * l.prix_vendu)                               as total,
         sum(l.quantite * l.prix_achat_snapshot)                      as cout,
         sum(l.quantite * greatest(l.prix_vendu - coalesce(l.prix_habituel_snapshot, l.prix_vendu), 0)) as gain_au_dessus,
         sum(l.quantite * greatest(coalesce(l.prix_habituel_snapshot, l.prix_vendu) - l.prix_vendu, 0)) as cout_remises
  from public.lignes_commande l
  group by l.commande_id
),
payes as (
  select p.commande_id,
         sum(p.montant)       as total_paye,
         max(p.date_paiement) as dernier_paiement
  from public.paiements p
  group by p.commande_id
),
calc as (
  select c.*,
         coalesce(l.nb_pieces, 0)                      as nb_pieces,
         coalesce(l.total, 0)                          as total_articles,
         coalesce(l.total, 0) + c.frais_livraison      as total_du,
         coalesce(l.cout, 0)                           as cout,
         coalesce(l.gain_au_dessus, 0)                 as gain_au_dessus,
         coalesce(l.cout_remises, 0)                   as cout_remises,
         coalesce(p.total_paye, 0)                     as total_paye,
         p.dernier_paiement
  from public.commandes c
  left join lignes l on l.commande_id = c.id
  left join payes p  on p.commande_id = c.id
)
select k.id,
       k.boutique_id,
       k.user_id,
       k.created_at,
       k.client_id,
       cl.nom                                         as client_nom,
       cl.telephone                                   as client_telephone,
       k.date_commande,
       k.statut_livraison,
       k.note,
       k.nb_pieces,
       k.total_du                                     as total,
       k.cout,
       k.total_articles - k.cout                      as benefice,
       k.gain_au_dessus,
       k.cout_remises,
       k.gain_au_dessus - k.cout_remises              as ecart_prix_habituel,
       k.total_paye,
       case when k.statut_livraison = 'annulee' then 0
            else greatest(k.total_du - k.total_paye, 0)
       end                                            as reste_a_payer,
       case when k.total_paye = 0        then 'non_payee'
            when k.total_paye < k.total_du then 'partiellement_payee'
            else 'soldee'
       end                                            as statut_paiement,
       k.dernier_paiement,
       k.type,
       k.date_livraison,
       k.mode_remise,
       k.adresse_livraison,
       k.frais_livraison,
       k.total_articles,
       (k.statut_livraison <> 'annulee'
        and (k.type = 'vente'
             or k.statut_livraison = 'livree'
             or (k.total_paye > 0 and k.total_paye >= k.total_du)))
                                                      as comptee
from calc k
left join public.clients cl on cl.id = k.client_id;

comment on column public.v_commandes.comptee is
  'Vrai si c''est une vente : vente au comptoir, ou commande payée en entier ou livrée. Faux pour une commande en cours ou annulée.';

-- ─── v_clients : achats et dettes = ventes comptées seulement ───────

create or replace view public.v_clients
with (security_invoker = true)
as
select cl.id,
       cl.boutique_id,
       cl.created_at,
       cl.nom,
       cl.telephone,
       count(vc.id) filter (where vc.comptee)::integer                       as nb_achats,
       coalesce(sum(vc.total) filter (where vc.comptee), 0)                  as total_achats,
       coalesce(sum(vc.reste_a_payer) filter (where vc.comptee), 0)          as total_du,
       count(vc.id) filter (where vc.comptee and vc.reste_a_payer > 0)::integer as nb_impayes,
       max(vc.date_commande) filter (where vc.comptee)                       as dernier_achat
from public.clients cl
left join public.v_commandes vc on vc.client_id = cl.id
group by cl.id;

-- ─── v_dashboard : indicateurs sur les ventes comptées ──────────────

create or replace view public.v_dashboard
with (security_invoker = true)
as
select b.id as boutique_id,
       b.devise_reference,
       b.taux_usd_cdf,
       s.total_approvisionne,
       s.valeur_stock_restant,
       s.pieces_en_stock,
       s.articles_epuises,
       v.chiffre_affaires,
       v.total_encaisse,
       v.reste_du,
       v.benefice_realise,
       v.gain_au_dessus,
       v.cout_remises,
       v.nb_commandes,
       coalesce(m.benefice_verse, 0)                        as benefice_verse,
       v.benefice_encaisse - coalesce(m.benefice_verse, 0)  as benefice_disponible,
       v.benefice_encaisse
from public.boutiques b
cross join lateral (
  select coalesce(sum(vs.total_approvisionne), 0)                      as total_approvisionne,
         coalesce(sum(vs.valeur_stock_restant), 0)                     as valeur_stock_restant,
         coalesce(sum(vs.quantite_restante), 0)::integer               as pieces_en_stock,
         count(*) filter (where vs.quantite_restante = 0)::integer     as articles_epuises
  from public.v_stock vs
  where vs.boutique_id = b.id
) s
cross join lateral (
  select coalesce(sum(vc.total) filter (where vc.comptee), 0)          as chiffre_affaires,
         -- Argent réellement reçu, avances des commandes en cours comprises.
         coalesce(sum(vc.total_paye), 0)                               as total_encaisse,
         coalesce(sum(vc.reste_a_payer) filter (where vc.comptee), 0)  as reste_du,
         coalesce(sum(vc.benefice) filter (where vc.comptee), 0)       as benefice_realise,
         coalesce(sum(vc.benefice) filter (where vc.statut_paiement = 'soldee'), 0)
                                                                       as benefice_encaisse,
         coalesce(sum(vc.gain_au_dessus) filter (where vc.comptee), 0) as gain_au_dessus,
         coalesce(sum(vc.cout_remises) filter (where vc.comptee), 0)   as cout_remises,
         count(*) filter (where vc.comptee)::integer                   as nb_commandes
  from public.v_commandes vc
  where vc.boutique_id = b.id
    and vc.statut_livraison <> 'annulee'
) v
left join lateral (
  select sum(mv.montant) as benefice_verse
  from public.mouvements mv
  where mv.boutique_id = b.id and mv.source = 'boutique'
) m on true;

-- ─── Statistiques sur une période ───────────────────────────────────

create or replace function public.dashboard_periode(p_debut date, p_fin date)
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
    where vc.comptee
      and vc.date_commande between p_debut and p_fin
  )
  select
    (select coalesce(sum(a.quantite_achetee * a.prix_achat), 0)
       from public.articles a
      where a.date_appro between p_debut and p_fin),
    v.chiffre_affaires,
    v.cout_ventes,
    v.benefice,
    -- Argent réellement reçu pendant la période (avances comprises).
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

create or replace function public.articles_vendus_periode(p_debut date, p_fin date)
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
  join public.v_commandes vc on vc.id = l.commande_id
  join public.articles a     on a.id = l.article_id
  where vc.comptee
    and vc.date_commande between p_debut and p_fin
  group by a.id, a.nom, a.categorie, a.taille
  order by sum(l.quantite) desc, a.nom
$$;

commit;
