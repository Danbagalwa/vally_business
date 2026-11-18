-- ════════════════════════════════════════════════════════════════════
--  Vally Business — mise à jour du 18/11/2026 : Mes dépenses
--
--  À coller dans Supabase : SQL Editor → New query → Run.
--  À exécuter UNE FOIS, après 2026-11-18_ventes_commandes.sql.
-- ════════════════════════════════════════════════════════════════════

begin;

-- ════════════════════════════════════════════════════════════════════
--  Vally Business — Mes dépenses : on ne se verse que de l'argent reçu
--
--  Bénéfice encaissé = bénéfice des ventes et commandes SOLDÉES (payées
--  en entier) et non annulées. Tant qu'un client doit encore quelque
--  chose, le bénéfice de cette vente reste en attente.
--  Bénéfice disponible = bénéfice encaissé − déjà versé dans Mes dépenses.
-- ════════════════════════════════════════════════════════════════════

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
  select coalesce(sum(vc.total), 0)          as chiffre_affaires,
         coalesce(sum(vc.total_paye), 0)     as total_encaisse,
         coalesce(sum(vc.reste_a_payer), 0)  as reste_du,
         coalesce(sum(vc.benefice), 0)       as benefice_realise,
         coalesce(sum(vc.benefice) filter (where vc.statut_paiement = 'soldee'), 0)
                                             as benefice_encaisse,
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

comment on view public.v_dashboard is 'Indicateurs actuels. Bénéfice disponible = bénéfice des ventes soldées − bénéfice déjà versé dans Mes dépenses.';

-- « Me verser un bénéfice » : plafonné au bénéfice déjà encaissé.
create or replace function public.verser_benefice(
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
            where vc.boutique_id = v_boutique
              and vc.statut_livraison <> 'annulee'
              and vc.statut_paiement = 'soldee'), 0)
         - coalesce((
            select sum(mv.montant) from public.mouvements mv
            where mv.boutique_id = v_boutique and mv.source = 'boutique'), 0))
    into v_disponible;

  if v_montant > v_disponible then
    raise exception using
      message = format('Bénéfice encaissé disponible insuffisant : il reste %s %s. '
                       'Seules les ventes payées en entier comptent.',
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

commit;
