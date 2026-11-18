-- ════════════════════════════════════════════════════════════════════
--  Vally Business — refonte : ventes ≠ commandes, livraison, clients,
--  articles enfant / adulte
--
--  • Vente    : au comptoir, remise tout de suite (statut « livree »).
--  • Commande : remise plus tard, date de livraison obligatoire,
--               retrait en boutique ou livraison (adresse, frais).
--               Le stock est réservé dès la commande.
--  • Frais de livraison : ajoutés à ce que le client paie, mais pas au
--    bénéfice (ils couvrent le livreur).
-- ════════════════════════════════════════════════════════════════════

-- ─── Articles : enfant ou adulte (adulte par défaut) ────────────────

alter table public.articles
  add column pour_enfant boolean not null default false;

-- ─── Commandes : type, livraison ────────────────────────────────────

alter table public.commandes
  add column type              text not null default 'vente'
                               check (type in ('vente', 'commande')),
  add column date_livraison    date,
  add column mode_remise       text check (mode_remise in ('retrait', 'livraison')),
  add column adresse_livraison text,
  add column frais_livraison   numeric(14, 2) not null default 0
                               check (frais_livraison >= 0),
  add constraint commandes_commande_a_une_date
    check (type = 'vente' or date_livraison is not null);

-- Nouveau statut « prete » (commande préparée, en attente du client).
alter table public.commandes drop constraint commandes_statut_livraison_check;
alter table public.commandes add constraint commandes_statut_livraison_check
  check (statut_livraison in ('en_attente', 'prete', 'livree', 'annulee'));

create index commandes_a_livrer_idx on public.commandes (boutique_id, date_livraison)
  where type = 'commande' and statut_livraison in ('en_attente', 'prete');

-- ─── Vues : nouvelles colonnes ajoutées à la fin ────────────────────

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
       v.derniere_vente,
       a.pour_enfant
from public.articles a
left join vendu v on v.article_id = a.id;

-- total = articles + frais de livraison ; bénéfice = articles − coût.
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
       k.total_articles
from calc k
left join public.clients cl on cl.id = k.client_id;

-- ─── v_clients : ce que chaque client a acheté et ce qu'il doit ─────

create view public.v_clients
with (security_invoker = true)
as
select cl.id,
       cl.boutique_id,
       cl.created_at,
       cl.nom,
       cl.telephone,
       count(vc.id) filter (where vc.statut_livraison <> 'annulee')::integer      as nb_achats,
       coalesce(sum(vc.total) filter (where vc.statut_livraison <> 'annulee'), 0) as total_achats,
       coalesce(sum(vc.reste_a_payer), 0)                                         as total_du,
       count(vc.id) filter (where vc.reste_a_payer > 0)::integer                  as nb_impayes,
       max(vc.date_commande) filter (where vc.statut_livraison <> 'annulee')      as dernier_achat
from public.clients cl
left join public.v_commandes vc on vc.client_id = cl.id
group by cl.id;

comment on view public.v_clients is 'Clients avec nombre d''achats, total acheté et total dû (dettes).';

-- ─── creer_commande : vente au comptoir OU commande à livrer ────────

drop function if exists public.creer_commande(jsonb, uuid, text, text, date, text, jsonb);

create function public.creer_commande(
  p_lignes            jsonb,                  -- [{"article_id", "quantite", "prix_vendu"}]
  p_type              text default 'vente',   -- 'vente' | 'commande'
  p_client_id         uuid default null,
  p_client_nom        text default null,
  p_client_telephone  text default null,
  p_date              date default current_date,
  p_note              text default null,
  p_paiement          jsonb default null,     -- {"montant_saisi", "devise_saisie", "mode"}
  p_date_livraison    date default null,
  p_mode_remise       text default null,      -- 'retrait' | 'livraison'
  p_adresse_livraison text default null,
  p_frais_livraison   numeric default 0
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_client   uuid := p_client_id;
  v_commande uuid;
  v_ligne    jsonb;
begin
  if p_lignes is null or jsonb_typeof(p_lignes) <> 'array'
     or jsonb_array_length(p_lignes) = 0 then
    raise exception using
      message = 'Ajoute au moins un article.',
      hint = 'commande_vide';
  end if;

  if v_client is null and nullif(btrim(p_client_nom), '') is not null then
    insert into public.clients (nom, telephone)
    values (btrim(p_client_nom), nullif(btrim(p_client_telephone), ''))
    returning id into v_client;
  end if;

  if p_type = 'commande' then
    if v_client is null then
      raise exception using
        message = 'Indique le client de la commande.',
        hint = 'client_obligatoire';
    end if;
    if p_date_livraison is null then
      raise exception using
        message = 'Indique la date de livraison.',
        hint = 'date_livraison_obligatoire';
    end if;
  end if;

  insert into public.commandes
    (type, client_id, date_commande, note, statut_livraison,
     date_livraison, mode_remise, adresse_livraison, frais_livraison)
  values
    (coalesce(p_type, 'vente'), v_client, coalesce(p_date, current_date),
     nullif(btrim(p_note), ''),
     case when p_type = 'commande' then 'en_attente' else 'livree' end,
     case when p_type = 'commande' then p_date_livraison end,
     case when p_type = 'commande' then coalesce(p_mode_remise, 'retrait') end,
     case when p_type = 'commande' and p_mode_remise = 'livraison'
          then nullif(btrim(p_adresse_livraison), '') end,
     case when p_type = 'commande' and p_mode_remise = 'livraison'
          then coalesce(p_frais_livraison, 0) else 0 end)
  returning id into v_commande;

  -- Prix figés et contrôle du stock : déclencheur des lignes.
  for v_ligne in select * from jsonb_array_elements(p_lignes)
  loop
    insert into public.lignes_commande (commande_id, article_id, quantite, prix_vendu)
    values (v_commande,
            (v_ligne ->> 'article_id')::uuid,
            (v_ligne ->> 'quantite')::integer,
            (v_ligne ->> 'prix_vendu')::numeric);
  end loop;

  -- Conversion de devise : déclencheur des paiements.
  if p_paiement is not null then
    insert into public.paiements (commande_id, montant_saisi, devise_saisie, mode, date_paiement)
    values (v_commande,
            (p_paiement ->> 'montant_saisi')::numeric,
            p_paiement ->> 'devise_saisie',
            coalesce(p_paiement ->> 'mode', 'especes'),
            coalesce(p_date, current_date));
  end if;

  return v_commande;
end;
$$;

revoke all on function public.creer_commande(jsonb, text, uuid, text, text, date, text, jsonb, date, text, text, numeric) from public, anon;
grant execute on function public.creer_commande(jsonb, text, uuid, text, text, date, text, jsonb, date, text, text, numeric) to authenticated;
