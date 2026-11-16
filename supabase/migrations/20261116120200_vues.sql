-- ════════════════════════════════════════════════════════════════════
--  Vally Business — 3/6 : vues calculées
--
--  Toutes les vues sont en security_invoker : elles appliquent les règles
--  RLS de la personne connectée (elle ne voit que sa boutique).
--  Les commandes annulées sortent de tous les calculs d'argent et de stock.
-- ════════════════════════════════════════════════════════════════════

-- ─── v_stock : un article par ligne, avec son stock restant ─────────

create view public.v_stock
with (security_invoker = true)
as
with vendu as (
  select l.article_id,
         sum(l.quantite)::integer as quantite_vendue,
         max(c.date_commande)     as derniere_vente
  from public.lignes_commande l
  join public.commandes c on c.id = l.commande_id
  where c.statut_livraison <> 'annulee'
  group by l.article_id
)
select a.id,
       a.boutique_id,
       a.user_id,
       a.created_at,
       a.nom,
       a.categorie,
       a.taille,
       a.couleur,
       a.quantite_achetee,
       a.prix_achat,
       a.prix_vente_habituel,
       a.fournisseur,
       a.date_appro,
       a.photo_url,
       coalesce(v.quantite_vendue, 0)                                   as quantite_vendue,
       a.quantite_achetee - coalesce(v.quantite_vendue, 0)              as quantite_restante,
       a.quantite_achetee * a.prix_achat                                as total_approvisionne,
       (a.quantite_achetee - coalesce(v.quantite_vendue, 0)) * a.prix_achat as valeur_stock_restant,
       v.derniere_vente
from public.articles a
left join vendu v on v.article_id = a.id;

comment on view public.v_stock is 'Articles avec quantité vendue, quantité restante et valeur du stock restant.';

-- ─── v_commandes : totaux, bénéfice et paiement par commande ────────

create view public.v_commandes
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
)
select c.id,
       c.boutique_id,
       c.user_id,
       c.created_at,
       c.client_id,
       cl.nom                                         as client_nom,
       cl.telephone                                   as client_telephone,
       c.date_commande,
       c.statut_livraison,
       c.note,
       coalesce(l.nb_pieces, 0)                       as nb_pieces,
       coalesce(l.total, 0)                           as total,
       coalesce(l.cout, 0)                            as cout,
       coalesce(l.total, 0) - coalesce(l.cout, 0)     as benefice,
       coalesce(l.gain_au_dessus, 0)                  as gain_au_dessus,
       coalesce(l.cout_remises, 0)                    as cout_remises,
       coalesce(l.gain_au_dessus, 0) - coalesce(l.cout_remises, 0) as ecart_prix_habituel,
       coalesce(p.total_paye, 0)                      as total_paye,
       case when c.statut_livraison = 'annulee' then 0
            else greatest(coalesce(l.total, 0) - coalesce(p.total_paye, 0), 0)
       end                                            as reste_a_payer,
       case when coalesce(p.total_paye, 0) = 0                   then 'non_payee'
            when coalesce(p.total_paye, 0) < coalesce(l.total, 0) then 'partiellement_payee'
            else 'soldee'
       end                                            as statut_paiement,
       p.dernier_paiement
from public.commandes c
left join lignes l      on l.commande_id = c.id
left join payes p       on p.commande_id = c.id
left join public.clients cl on cl.id = c.client_id;

comment on view public.v_commandes is 'Commandes avec total, coût, bénéfice, payé, reste à payer et statut de paiement (non_payee / partiellement_payee / soldee).';

-- ─── v_dashboard : indicateurs actuels de la boutique ───────────────
-- (pour une période précise : fonction dashboard_periode)

create view public.v_dashboard
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
       v.benefice_realise - coalesce(m.benefice_verse, 0)   as benefice_disponible
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
  select coalesce(sum(vc.total), 0)          as chiffre_affaires,
         coalesce(sum(vc.total_paye), 0)     as total_encaisse,
         coalesce(sum(vc.reste_a_payer), 0)  as reste_du,
         coalesce(sum(vc.benefice), 0)       as benefice_realise,
         coalesce(sum(vc.gain_au_dessus), 0) as gain_au_dessus,
         coalesce(sum(vc.cout_remises), 0)   as cout_remises,
         count(*)::integer                   as nb_commandes
  from public.v_commandes vc
  where vc.boutique_id = b.id
    and vc.statut_livraison <> 'annulee'
) v
left join lateral (
  select sum(mv.montant) as benefice_verse
  from public.mouvements mv
  where mv.boutique_id = b.id and mv.source = 'boutique'
) m on true;

comment on view public.v_dashboard is 'Indicateurs actuels de la boutique, dont bénéfice disponible = bénéfice réalisé − bénéfice déjà versé dans Mes dépenses.';

-- ─── v_flux_mensuel : Mes dépenses, mois par mois ───────────────────

create view public.v_flux_mensuel
with (security_invoker = true)
as
with mois as (
  select mv.boutique_id,
         date_trunc('month', mv.date_mouvement)::date                         as mois,
         coalesce(sum(mv.montant) filter (where mv.type = 'entree'), 0)       as entrees,
         coalesce(sum(mv.montant) filter (where mv.type = 'sortie'), 0)       as sorties,
         coalesce(sum(mv.montant) filter (where mv.source = 'boutique'), 0)   as dont_versements_boutique
  from public.mouvements mv
  group by mv.boutique_id, date_trunc('month', mv.date_mouvement)
)
select boutique_id,
       mois,
       entrees,
       sorties,
       entrees - sorties                                                         as solde_mois,
       sum(entrees - sorties) over (partition by boutique_id order by mois)      as solde_cumule,
       dont_versements_boutique
from mois;

comment on view public.v_flux_mensuel is 'Mes dépenses : entrées, sorties, solde du mois et solde cumulé.';
