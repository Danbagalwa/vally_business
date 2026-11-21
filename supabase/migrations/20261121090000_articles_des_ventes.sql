-- ════════════════════════════════════════════════════════════════════
--  Vally Business — les articles de chaque vente dans v_commandes
--
--  Le cahier de caisse affiche ce qui a été vendu (« Robe pagne fleurie,
--  2 × Chemise wax ») au lieu d'un simple nombre de pièces.
--  Nouvelle colonne, en fin de vue : articles_resume, un tableau JSON
--  [{ "nom": "…", "quantite": 2 }, …] dans l'ordre de saisie des lignes
--  ([] pour une vente sans ligne). Aucune table ne change.
-- ════════════════════════════════════════════════════════════════════

create or replace view public.v_commandes
with (security_invoker = true)
as
with lignes as (
  select l.commande_id,
         sum(l.quantite)::integer                                     as nb_pieces,
         sum(l.quantite * l.prix_vendu)                               as total,
         sum(l.quantite * l.prix_achat_snapshot)                      as cout,
         sum(l.quantite * greatest(l.prix_vendu - coalesce(l.prix_habituel_snapshot, l.prix_vendu), 0)) as gain_au_dessus,
         sum(l.quantite * greatest(coalesce(l.prix_habituel_snapshot, l.prix_vendu) - l.prix_vendu, 0)) as cout_remises,
         -- Une ligne = un article (clé primaire) : la jointure ne double rien.
         jsonb_agg(jsonb_build_object('nom', a.nom, 'quantite', l.quantite)
                   order by l.created_at, l.id)                       as articles_resume
  from public.lignes_commande l
  left join public.articles a on a.id = l.article_id
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
         coalesce(l.articles_resume, '[]'::jsonb)      as articles_resume,
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
                                                      as comptee,
       k.numero,
       k.articles_resume
from calc k
left join public.clients cl on cl.id = k.client_id;
