-- ════════════════════════════════════════════════════════════════════
--  Vally Business — numéros de facture
--
--  Chaque vente / commande reçoit un numéro « AAAA-0001 », suivi par
--  boutique et par année. Il est attribué par la base (compteur
--  verrouillé : deux téléphones ne peuvent pas obtenir le même) et ne
--  change plus jamais.
-- ════════════════════════════════════════════════════════════════════

create table public.compteurs_factures (
  boutique_id uuid not null references public.boutiques (id) on delete cascade,
  annee       integer not null,
  dernier     integer not null default 0 check (dernier >= 0),
  primary key (boutique_id, annee)
);
-- Lu et écrit uniquement par le déclencheur (SECURITY DEFINER).
alter table public.compteurs_factures enable row level security;
revoke all on public.compteurs_factures from anon, authenticated;

alter table public.commandes add column numero text;

-- Numéros des ventes déjà enregistrées, dans l'ordre de création.
with numerotees as (
  select id,
         extract(year from date_commande)::integer as annee,
         row_number() over (partition by boutique_id, extract(year from date_commande)
                            order by created_at, id) as n
  from public.commandes
)
update public.commandes c
   set numero = x.annee || '-' || lpad(x.n::text, 4, '0')
  from numerotees x
 where x.id = c.id;

insert into public.compteurs_factures (boutique_id, annee, dernier)
select boutique_id, extract(year from date_commande)::integer, count(*)
  from public.commandes
 group by boutique_id, extract(year from date_commande)::integer;

alter table public.commandes alter column numero set not null;
alter table public.commandes
  add constraint commandes_numero_unique unique (boutique_id, numero);

create function private.tg_numero_facture()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_annee integer := extract(year from coalesce(new.date_commande, current_date))::integer;
  v_n     integer;
begin
  if tg_op = 'UPDATE' then
    new.numero := old.numero;            -- un numéro ne change jamais
    return new;
  end if;
  insert into public.compteurs_factures as c (boutique_id, annee, dernier)
  values (new.boutique_id, v_annee, 1)
  on conflict (boutique_id, annee) do update set dernier = c.dernier + 1
  returning c.dernier into v_n;
  new.numero := v_annee || '-' || lpad(v_n::text, 4, '0');
  return new;
end;
$$;

revoke all on function private.tg_numero_facture() from public, anon, authenticated;

create trigger commandes_numero
  before insert or update on public.commandes
  for each row execute function private.tg_numero_facture();

-- ─── v_commandes : colonne « numero » ajoutée à la fin ──────────────

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
                                                      as comptee,
       k.numero
from calc k
left join public.clients cl on cl.id = k.client_id;
