-- ════════════════════════════════════════════════════════════════════
--  Vally Business — deux rayons : Habits et Parfums
--
--  La boutique vend aussi des parfums, comptés À PART : ventes, bénéfice,
--  stock et dettes se lisent par rayon.
--  • articles.rayon : 'habits' (par défaut) ou 'parfums' ;
--  • commandes.rayon : pris automatiquement du premier article vendu ;
--    une vente ou une commande ne mélange jamais les deux rayons.
--  • vues et statistiques : colonne rayon, et un paramètre p_rayon
--    (null = les deux rayons ensemble).
--  « Me verser un bénéfice » reste commun aux deux rayons.
-- ════════════════════════════════════════════════════════════════════

alter table public.articles add column rayon text not null default 'habits'
  constraint articles_rayon_valide check (rayon in ('habits', 'parfums'));
alter table public.commandes add column rayon text not null default 'habits'
  constraint commandes_rayon_valide check (rayon in ('habits', 'parfums'));
create index articles_boutique_rayon_idx on public.articles (boutique_id, rayon);
create index commandes_boutique_rayon_idx on public.commandes (boutique_id, rayon);

-- ─── Une vente = un seul rayon ──────────────────────────────────────
--  La première ligne donne son rayon à la vente ; les suivantes doivent
--  être du même rayon.
create function private.tg_lignes_rayon()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_article  text;
  v_commande text;
  v_autres   integer;
begin
  select a.rayon into v_article from public.articles a where a.id = new.article_id;
  select c.rayon into v_commande from public.commandes c where c.id = new.commande_id;
  select count(*) into v_autres
  from public.lignes_commande l
  where l.commande_id = new.commande_id and l.id <> new.id;

  if v_autres = 0 then
    if v_commande is distinct from v_article then
      update public.commandes set rayon = v_article where id = new.commande_id;
    end if;
  elsif v_commande is distinct from v_article then
    raise exception using
      message = 'Une vente contient soit des habits, soit des parfums : fais une vente à part pour cet article.',
      hint = 'rayon_melange';
  end if;
  return new;
end;
$$;
revoke all on function private.tg_lignes_rayon() from public, anon, authenticated;

create trigger lignes_commande_rayon
  before insert or update on public.lignes_commande
  for each row execute function private.tg_lignes_rayon();

-- Un article déjà vendu ne change plus de rayon (les comptes passés en dépendent).
create function private.tg_articles_rayon()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.rayon <> old.rayon and private.quantite_vendue(new.id) > 0 then
    raise exception using
      message = 'Cet article a déjà été vendu : il ne peut plus changer de rayon.',
      hint = 'rayon_fige';
  end if;
  return new;
end;
$$;
revoke all on function private.tg_articles_rayon() from public, anon, authenticated;

create trigger articles_rayon
  before update of rayon on public.articles
  for each row execute function private.tg_articles_rayon();

-- Une vente qui a des lignes garde le rayon de ses articles.
create function private.tg_commandes_rayon()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.rayon <> old.rayon and exists (
       select 1 from public.lignes_commande l
       join public.articles a on a.id = l.article_id
       where l.commande_id = new.id and a.rayon <> new.rayon) then
    raise exception using
      message = 'Le rayon d''une vente suit celui de ses articles.',
      hint = 'rayon_fige';
  end if;
  return new;
end;
$$;
revoke all on function private.tg_commandes_rayon() from public, anon, authenticated;

create trigger commandes_rayon
  before update of rayon on public.commandes
  for each row execute function private.tg_commandes_rayon();

-- ─── v_stock : colonne rayon ajoutée en fin ─────────────────────────

create or replace view public.v_stock
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
),
achats as (
  select ap.article_id,
         sum(ap.quantite * ap.prix_achat) as total,
         count(*)::integer                as nb
  from public.approvisionnements ap
  group by ap.article_id
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
       coalesce(ach.total, a.quantite_achetee * a.prix_achat)           as total_approvisionne,
       (a.quantite_achetee - coalesce(v.quantite_vendue, 0)) * a.prix_achat as valeur_stock_restant,
       v.derniere_vente,
       a.pour_enfant,
       coalesce(ach.nb, 1)                                              as nb_achats,
       a.rayon
from public.articles a
left join vendu v    on v.article_id = a.id
left join achats ach on ach.article_id = a.id;

-- ─── v_commandes : colonne rayon ajoutée en fin ─────────────────────

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
       k.articles_resume,
       k.rayon
from calc k
left join public.clients cl on cl.id = k.client_id;

-- ─── v_clients : ce que chaque client doit, par rayon (en fin) ──────

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
       max(vc.date_commande) filter (where vc.comptee)                       as dernier_achat,
       coalesce(sum(vc.reste_a_payer) filter (where vc.comptee and vc.rayon = 'habits'), 0)  as du_habits,
       coalesce(sum(vc.reste_a_payer) filter (where vc.comptee and vc.rayon = 'parfums'), 0) as du_parfums
from public.clients cl
left join public.v_commandes vc on vc.client_id = cl.id
group by cl.id;

-- ─── v_dashboard_rayon : les indicateurs actuels de chaque rayon ────
--  Mêmes colonnes que v_dashboard (qui reste le total des deux rayons).
--  Versé et disponible restent communs : « Me verser un bénéfice » puise
--  dans les deux rayons.

create view public.v_dashboard_rayon
with (security_invoker = true)
as
select d.boutique_id,
       r.rayon,
       d.devise_reference,
       d.taux_usd_cdf,
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
       d.benefice_verse,
       d.benefice_disponible,
       v.benefice_encaisse
from public.v_dashboard d
cross join (values ('habits'), ('parfums')) as r (rayon)
cross join lateral (
  select coalesce(sum(vs.total_approvisionne), 0)                      as total_approvisionne,
         coalesce(sum(vs.valeur_stock_restant), 0)                     as valeur_stock_restant,
         coalesce(sum(vs.quantite_restante), 0)::integer               as pieces_en_stock,
         count(*) filter (where vs.quantite_restante = 0)::integer     as articles_epuises
  from public.v_stock vs
  where vs.boutique_id = d.boutique_id and vs.rayon = r.rayon
) s
cross join lateral (
  select coalesce(sum(vc.total) filter (where vc.comptee), 0)          as chiffre_affaires,
         coalesce(sum(vc.total_paye), 0)                               as total_encaisse,
         coalesce(sum(vc.reste_a_payer) filter (where vc.comptee), 0)  as reste_du,
         coalesce(sum(vc.benefice) filter (where vc.comptee), 0)       as benefice_realise,
         coalesce(sum(vc.benefice) filter (where vc.statut_paiement = 'soldee'), 0)
                                                                       as benefice_encaisse,
         coalesce(sum(vc.gain_au_dessus) filter (where vc.comptee), 0) as gain_au_dessus,
         coalesce(sum(vc.cout_remises) filter (where vc.comptee), 0)   as cout_remises,
         count(*) filter (where vc.comptee)::integer                   as nb_commandes
  from public.v_commandes vc
  where vc.boutique_id = d.boutique_id
    and vc.rayon = r.rayon
    and vc.statut_livraison <> 'annulee'
) v;
grant select on public.v_dashboard_rayon to authenticated;

-- ─── Statistiques d'une période, pour un rayon (null = les deux) ────

drop function public.dashboard_periode(date, date);
create function public.dashboard_periode(p_debut date, p_fin date, p_rayon text default null)
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
      and (p_rayon is null or vc.rayon = p_rayon)
  )
  select
    (select coalesce(sum(ap.quantite * ap.prix_achat), 0)
       from public.approvisionnements ap
       join public.articles a on a.id = ap.article_id
      where ap.date_appro between p_debut and p_fin
        and (p_rayon is null or a.rayon = p_rayon)),
    v.chiffre_affaires,
    v.cout_ventes,
    v.benefice,
    -- Argent réellement reçu pendant la période (avances comprises).
    (select coalesce(sum(p.montant), 0)
       from public.paiements p
       join public.commandes c on c.id = p.commande_id
      where c.statut_livraison <> 'annulee'
        and p.date_paiement between p_debut and p_fin
        and (p_rayon is null or c.rayon = p_rayon)),
    v.reste_du,
    v.gain_au_dessus,
    v.cout_remises,
    v.nb_commandes,
    v.pieces_vendues
  from v
$$;

drop function public.articles_vendus_periode(date, date);
create function public.articles_vendus_periode(p_debut date, p_fin date, p_rayon text default null)
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
    and (p_rayon is null or a.rayon = p_rayon)
  group by a.id, a.nom, a.categorie, a.taille
  order by sum(l.quantite) desc, a.nom
$$;

revoke all on function public.dashboard_periode(date, date, text) from public, anon;
revoke all on function public.articles_vendus_periode(date, date, text) from public, anon;
grant execute on function public.dashboard_periode(date, date, text) to authenticated;
grant execute on function public.articles_vendus_periode(date, date, text) to authenticated;
