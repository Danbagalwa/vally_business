-- ════════════════════════════════════════════════════════════════════
--  Vally Business — script d'installation complet
--
--  À coller dans Supabase : SQL Editor → New query → Run.
--  À exécuter UNE SEULE FOIS, sur une base vide (nouveau projet).
--  Base déjà installée : utilise plutôt supabase/mises_a_jour/.
--  Tout s'exécute dans une transaction : en cas d'erreur, rien n'est créé.
--
--  Généré à partir de supabase/migrations/ (même contenu, même ordre).
-- ════════════════════════════════════════════════════════════════════

begin;


-- ▼▼▼ 20261116120000_tables.sql ▼▼▼

-- ════════════════════════════════════════════════════════════════════
--  Vally Business — 1/6 : tables
--
--  Une boutique est partagée par plusieurs comptes (tous admins).
--  Chaque table métier porte :
--    • id          uuid
--    • boutique_id la boutique propriétaire (base de la sécurité RLS)
--    • user_id     l'auteur de la ligne (→ auth.users)
--    • created_at
--  Tous les montants sont en numeric, dans la devise de référence de la
--  boutique (CDF ou USD).
-- ════════════════════════════════════════════════════════════════════

create schema if not exists private;

-- ─── Boutique et membres ────────────────────────────────────────────

create table public.boutiques (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid default auth.uid() references auth.users (id) on delete set null,
  created_at        timestamptz not null default now(),
  nom               text not null check (length(btrim(nom)) between 1 and 80),
  devise_reference  text not null default 'CDF' check (devise_reference in ('CDF', 'USD')),
  -- 1 USD = taux_usd_cdf CDF
  taux_usd_cdf      numeric(14, 4) not null check (taux_usd_cdf > 0),
  taux_maj_le       timestamptz not null default now()
);
comment on table public.boutiques is 'Boutique partagée entre ses membres.';
comment on column public.boutiques.devise_reference is 'Devise dans laquelle tous les montants sont enregistrés. Non modifiable.';
comment on column public.boutiques.taux_usd_cdf is 'Taux de change : 1 USD = x CDF.';

create table public.membres (
  id           uuid primary key default gen_random_uuid(),
  boutique_id  uuid not null references public.boutiques (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  created_at   timestamptz not null default now(),
  role         text not null default 'admin' check (role in ('admin')),
  ajoute_par   uuid default auth.uid() references auth.users (id) on delete set null,
  -- Un compte appartient à une seule boutique.
  constraint membres_un_compte_une_boutique unique (user_id)
);
create index membres_boutique_id_idx on public.membres (boutique_id);
create index membres_ajoute_par_idx on public.membres (ajoute_par);
create index boutiques_user_id_idx on public.boutiques (user_id);

-- Boutique du compte connecté (null s'il n'en a pas).
-- SECURITY DEFINER : lit membres sans repasser par RLS (évite la récursion).
create function private.ma_boutique()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.boutique_id
  from public.membres m
  where m.user_id = (select auth.uid())
$$;

-- ─── Stock ──────────────────────────────────────────────────────────

create table public.articles (
  id                   uuid primary key default gen_random_uuid(),
  boutique_id          uuid not null default private.ma_boutique()
                         references public.boutiques (id) on delete cascade,
  user_id              uuid default auth.uid() references auth.users (id) on delete set null,
  created_at           timestamptz not null default now(),
  nom                  text not null check (length(btrim(nom)) between 1 and 120),
  categorie            text not null check (length(btrim(categorie)) between 1 and 60),
  taille               text not null check (length(btrim(taille)) between 1 and 20),
  couleur              text check (couleur is null or length(btrim(couleur)) between 1 and 40),
  quantite_achetee     integer not null check (quantite_achetee > 0),
  -- Prix d'achat unitaire TOUS FRAIS COMPRIS (transport, douane, emballage).
  prix_achat           numeric(14, 2) not null check (prix_achat >= 0),
  -- Prix de vente habituel : obligatoire, pré-remplit le prix à la vente.
  prix_vente_habituel  numeric(14, 2) not null check (prix_vente_habituel >= 0),
  fournisseur          text,
  date_appro           date not null default current_date,
  photo_url            text,
  -- Cible des clés étrangères composites (même boutique garantie).
  constraint articles_id_boutique_key unique (id, boutique_id)
);
comment on column public.articles.prix_achat is 'Prix d''achat unitaire, tous frais compris.';
comment on column public.articles.photo_url is 'Chemin dans le bucket Storage « photos-articles ».';
create index articles_boutique_date_idx on public.articles (boutique_id, date_appro);
create index articles_user_id_idx on public.articles (user_id);

-- ─── Clients et commandes ───────────────────────────────────────────

create table public.clients (
  id           uuid primary key default gen_random_uuid(),
  boutique_id  uuid not null default private.ma_boutique()
                 references public.boutiques (id) on delete cascade,
  user_id      uuid default auth.uid() references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  nom          text not null check (length(btrim(nom)) between 1 and 120),
  telephone    text check (telephone is null or length(btrim(telephone)) between 3 and 30),
  constraint clients_id_boutique_key unique (id, boutique_id)
);
create index clients_boutique_id_idx on public.clients (boutique_id);
create index clients_user_id_idx on public.clients (user_id);

create table public.commandes (
  id                uuid primary key default gen_random_uuid(),
  boutique_id       uuid not null default private.ma_boutique()
                      references public.boutiques (id) on delete cascade,
  user_id           uuid default auth.uid() references auth.users (id) on delete set null,
  created_at        timestamptz not null default now(),
  client_id         uuid,
  date_commande     date not null default current_date,
  statut_livraison  text not null default 'en_attente'
                      check (statut_livraison in ('en_attente', 'livree', 'annulee')),
  note              text,
  constraint commandes_id_boutique_key unique (id, boutique_id),
  -- Le client doit appartenir à la même boutique ; s'il est supprimé,
  -- la commande reste (client_id passe à null, boutique_id est conservé).
  constraint commandes_client_fk foreign key (client_id, boutique_id)
    references public.clients (id, boutique_id) on delete set null (client_id)
);
create index commandes_boutique_date_idx on public.commandes (boutique_id, date_commande);
create index commandes_client_id_idx on public.commandes (client_id);
create index commandes_user_id_idx on public.commandes (user_id);

create table public.lignes_commande (
  id                      uuid primary key default gen_random_uuid(),
  boutique_id             uuid not null default private.ma_boutique()
                            references public.boutiques (id) on delete cascade,
  user_id                 uuid default auth.uid() references auth.users (id) on delete set null,
  created_at              timestamptz not null default now(),
  commande_id             uuid not null,
  article_id              uuid not null,
  quantite                integer not null check (quantite > 0),
  -- Prix réellement pratiqué (au-dessus ou en dessous du prix habituel).
  prix_vendu              numeric(14, 2) not null check (prix_vendu >= 0),
  -- Copies figées au moment de la vente (remplies par le serveur).
  prix_achat_snapshot     numeric(14, 2) not null check (prix_achat_snapshot >= 0),
  prix_habituel_snapshot  numeric(14, 2) check (prix_habituel_snapshot is null or prix_habituel_snapshot >= 0),
  constraint lignes_commande_article_unique unique (commande_id, article_id),
  constraint lignes_commande_commande_fk foreign key (commande_id, boutique_id)
    references public.commandes (id, boutique_id) on delete cascade,
  -- Un article déjà vendu ne peut pas être supprimé.
  constraint lignes_commande_article_fk foreign key (article_id, boutique_id)
    references public.articles (id, boutique_id) on delete restrict
);
create index lignes_commande_article_id_idx on public.lignes_commande (article_id);
create index lignes_commande_boutique_id_idx on public.lignes_commande (boutique_id);
create index lignes_commande_user_id_idx on public.lignes_commande (user_id);

create table public.paiements (
  id             uuid primary key default gen_random_uuid(),
  boutique_id    uuid not null default private.ma_boutique()
                   references public.boutiques (id) on delete cascade,
  user_id        uuid default auth.uid() references auth.users (id) on delete set null,
  created_at     timestamptz not null default now(),
  commande_id    uuid not null,
  -- Montant en devise de référence (calculé par le serveur).
  montant        numeric(14, 2) not null check (montant > 0),
  date_paiement  date not null default current_date,
  mode           text not null default 'especes'
                   check (mode in ('especes', 'mobile_money', 'virement', 'autre')),
  -- Ce que le client a réellement donné, et le taux appliqué si conversion.
  devise_saisie  text not null check (devise_saisie in ('CDF', 'USD')),
  montant_saisi  numeric(14, 2) not null check (montant_saisi > 0),
  taux_change    numeric(14, 4) check (taux_change is null or taux_change > 0),
  constraint paiements_commande_fk foreign key (commande_id, boutique_id)
    references public.commandes (id, boutique_id) on delete cascade
);
create index paiements_commande_id_idx on public.paiements (commande_id);
create index paiements_boutique_date_idx on public.paiements (boutique_id, date_paiement);
create index paiements_user_id_idx on public.paiements (user_id);

-- ─── Mes dépenses (partagé par la boutique, séparé des ventes) ──────

create table public.mouvements (
  id              uuid primary key default gen_random_uuid(),
  boutique_id     uuid not null default private.ma_boutique()
                    references public.boutiques (id) on delete cascade,
  user_id         uuid default auth.uid() references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  type            text not null check (type in ('entree', 'sortie')),
  -- Montant en devise de référence (calculé par le serveur).
  montant         numeric(14, 2) not null check (montant > 0),
  categorie       text not null check (length(btrim(categorie)) between 1 and 60),
  date_mouvement  date not null default current_date,
  note            text,
  -- « boutique » = versement de bénéfice (uniquement via verser_benefice()).
  source          text not null default 'manuel' check (source in ('manuel', 'boutique')),
  devise_saisie   text not null check (devise_saisie in ('CDF', 'USD')),
  montant_saisi   numeric(14, 2) not null check (montant_saisi > 0),
  taux_change     numeric(14, 4) check (taux_change is null or taux_change > 0),
  constraint mouvements_versement_est_entree check (source = 'manuel' or type = 'entree')
);
create index mouvements_boutique_date_idx on public.mouvements (boutique_id, date_mouvement);
create index mouvements_user_id_idx on public.mouvements (user_id);


-- ▼▼▼ 20261116120100_regles_metier.sql ▼▼▼

-- ════════════════════════════════════════════════════════════════════
--  Vally Business — 2/6 : règles métier (déclencheurs)
--
--  Les erreurs métier sont levées avec :
--    message = texte prêt à afficher (français, tutoiement)
--    hint    = code stable pour l'appli (ex. 'stock_insuffisant')
--
--  Le stock n'est pas stocké : quantité restante = quantité achetée
--  − Σ lignes des commandes NON annulées. Annuler une commande remet
--  donc automatiquement son stock.
-- ════════════════════════════════════════════════════════════════════

-- Quantité déjà vendue d'un article (commandes non annulées),
-- en excluant éventuellement une ligne ou une commande.
create function private.quantite_vendue(
  p_article_id uuid,
  p_sauf_ligne uuid default null,
  p_sauf_commande uuid default null
)
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(l.quantite), 0)::integer
  from public.lignes_commande l
  join public.commandes c on c.id = l.commande_id
  where l.article_id = p_article_id
    and c.statut_livraison <> 'annulee'
    and l.id is distinct from p_sauf_ligne
    and c.id is distinct from p_sauf_commande
$$;

-- Conversion d'un montant saisi vers la devise de référence de la boutique.
-- Renseigne montant et taux_change de la ligne (paiements, mouvements).
create function private.tg_convertir_montant()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_devise text;
  v_taux   numeric;
begin
  if new.montant_saisi is null or new.montant_saisi <= 0 then
    raise exception using
      message = 'Saisis un montant supérieur à zéro.',
      hint = 'montant_invalide';
  end if;

  select b.devise_reference, b.taux_usd_cdf
    into v_devise, v_taux
  from public.boutiques b
  where b.id = new.boutique_id;

  if not found then
    raise exception using
      message = 'Boutique introuvable.',
      hint = 'boutique_introuvable';
  end if;

  -- En modification, on garde le taux d'origine si la saisie ne change pas.
  if tg_op = 'UPDATE'
     and new.devise_saisie = old.devise_saisie
     and new.montant_saisi = old.montant_saisi then
    new.montant := old.montant;
    new.taux_change := old.taux_change;
    return new;
  end if;

  if new.devise_saisie = v_devise then
    new.montant := new.montant_saisi;
    new.taux_change := null;
  elsif new.devise_saisie = 'USD' then        -- USD saisi, référence CDF
    new.montant := round(new.montant_saisi * v_taux, 2);
    new.taux_change := v_taux;
  else                                        -- CDF saisi, référence USD
    new.montant := round(new.montant_saisi / v_taux, 2);
    new.taux_change := v_taux;
  end if;

  if new.montant <= 0 then
    raise exception using
      message = 'Montant trop petit après conversion.',
      hint = 'montant_trop_petit';
  end if;
  return new;
end;
$$;

-- ─── Boutiques ──────────────────────────────────────────────────────

create function private.tg_boutiques_maj()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.devise_reference <> old.devise_reference then
    raise exception using
      message = 'La devise de référence ne peut pas être changée.',
      hint = 'devise_non_modifiable';
  end if;
  if new.taux_usd_cdf <> old.taux_usd_cdf then
    new.taux_maj_le := now();
  end if;
  new.id := old.id;
  new.user_id := old.user_id;
  new.created_at := old.created_at;
  return new;
end;
$$;

create trigger boutiques_maj
  before update on public.boutiques
  for each row execute function private.tg_boutiques_maj();

-- ─── Articles ───────────────────────────────────────────────────────

-- On ne peut pas descendre la quantité achetée sous la quantité vendue.
create function private.tg_articles_maj()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_vendu integer;
begin
  if new.quantite_achetee < old.quantite_achetee then
    v_vendu := private.quantite_vendue(new.id);
    if new.quantite_achetee < v_vendu then
      raise exception using
        message = format('Tu as déjà vendu %s pièce(s) de cet article : la quantité achetée ne peut pas être plus petite.', v_vendu),
        hint = 'quantite_sous_vendu';
    end if;
  end if;
  new.user_id := old.user_id;
  new.created_at := old.created_at;
  return new;
end;
$$;

create trigger articles_maj
  before update on public.articles
  for each row execute function private.tg_articles_maj();

-- ─── Lignes de commande ─────────────────────────────────────────────

-- • fige les prix (snapshots) à la création ;
-- • interdit de vendre plus que le stock restant (verrou sur l'article
--   pour que deux ventes simultanées ne dépassent pas le stock) ;
-- • interdit de modifier une commande annulée.
create function private.tg_lignes_controle()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_article public.articles%rowtype;
  v_statut  text;
  v_vendu   integer;
begin
  if tg_op = 'UPDATE'
     and (new.commande_id <> old.commande_id or new.article_id <> old.article_id) then
    raise exception using
      message = 'Supprime la ligne et ajoute l''article voulu à la place.',
      hint = 'ligne_non_modifiable';
  end if;

  select c.statut_livraison into v_statut
  from public.commandes c
  where c.id = new.commande_id and c.boutique_id = new.boutique_id;

  if v_statut = 'annulee' then
    raise exception using
      message = 'Cette commande est annulée : elle ne peut plus être modifiée.',
      hint = 'commande_annulee';
  end if;

  select a.* into v_article
  from public.articles a
  where a.id = new.article_id and a.boutique_id = new.boutique_id
  for update;

  if not found then
    raise exception using
      message = 'Article introuvable.',
      hint = 'article_introuvable';
  end if;

  if tg_op = 'INSERT' then
    new.prix_achat_snapshot := v_article.prix_achat;
    new.prix_habituel_snapshot := v_article.prix_vente_habituel;
  else
    new.prix_achat_snapshot := old.prix_achat_snapshot;
    new.prix_habituel_snapshot := old.prix_habituel_snapshot;
    new.user_id := old.user_id;
    new.created_at := old.created_at;
  end if;

  v_vendu := private.quantite_vendue(new.article_id, p_sauf_ligne => new.id);
  if v_vendu + new.quantite > v_article.quantite_achetee then
    raise exception using
      message = format('Stock insuffisant : il reste %s pièce(s) de « %s ».',
                       v_article.quantite_achetee - v_vendu, v_article.nom),
      hint = 'stock_insuffisant';
  end if;

  return new;
end;
$$;

create trigger lignes_commande_controle
  before insert or update on public.lignes_commande
  for each row execute function private.tg_lignes_controle();

-- ─── Commandes ──────────────────────────────────────────────────────

-- Réactiver une commande annulée reprend du stock : on revérifie.
create function private.tg_commandes_maj()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_ligne record;
  v_vendu integer;
begin
  if old.statut_livraison = 'annulee' and new.statut_livraison <> 'annulee' then
    for v_ligne in
      select l.article_id, l.quantite, a.nom, a.quantite_achetee
      from public.lignes_commande l
      join public.articles a on a.id = l.article_id
      where l.commande_id = new.id
      order by l.article_id          -- ordre fixe : évite les interblocages
      for update of a
    loop
      v_vendu := private.quantite_vendue(v_ligne.article_id, p_sauf_commande => new.id);
      if v_vendu + v_ligne.quantite > v_ligne.quantite_achetee then
        raise exception using
          message = format('Impossible de réactiver : il reste %s pièce(s) de « %s ».',
                           v_ligne.quantite_achetee - v_vendu, v_ligne.nom),
          hint = 'stock_insuffisant';
      end if;
    end loop;
  end if;
  new.user_id := old.user_id;
  new.created_at := old.created_at;
  return new;
end;
$$;

create trigger commandes_maj
  before update on public.commandes
  for each row execute function private.tg_commandes_maj();

-- ─── Paiements ──────────────────────────────────────────────────────

create function private.tg_paiements_controle()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.commandes c
    where c.id = new.commande_id and c.statut_livraison = 'annulee'
  ) then
    raise exception using
      message = 'Cette commande est annulée : tu ne peux pas y ajouter de paiement.',
      hint = 'commande_annulee';
  end if;
  if tg_op = 'UPDATE' then
    new.user_id := old.user_id;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

create trigger paiements_controle
  before insert or update on public.paiements
  for each row execute function private.tg_paiements_controle();

-- Déclenché après paiements_controle (ordre alphabétique des noms).
create trigger paiements_conversion
  before insert or update on public.paiements
  for each row execute function private.tg_convertir_montant();

-- ─── Mouvements ─────────────────────────────────────────────────────

create function private.tg_figer_auteur()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.user_id := old.user_id;
  new.created_at := old.created_at;
  return new;
end;
$$;

create trigger mouvements_conversion
  before insert or update on public.mouvements
  for each row execute function private.tg_convertir_montant();

create trigger mouvements_maj
  before update on public.mouvements
  for each row execute function private.tg_figer_auteur();

-- Clients : auteur et date de création non modifiables (même fonction).
create trigger clients_maj
  before update on public.clients
  for each row execute function private.tg_figer_auteur();


-- ▼▼▼ 20261116120200_vues.sql ▼▼▼

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


-- ▼▼▼ 20261116120300_fonctions.sql ▼▼▼

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


-- ▼▼▼ 20261116120400_securite_rls.sql ▼▼▼

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


-- ▼▼▼ 20261116120500_storage_photos.sql ▼▼▼

-- ════════════════════════════════════════════════════════════════════
--  Vally Business — 6/6 : photos des articles (Supabase Storage)
--
--  Bucket privé « photos-articles ». Chemin des fichiers :
--    <boutique_id>/<article_id>.jpg
--  Chaque membre ne lit et n'écrit que dans le dossier de sa boutique.
--  L'appli affiche les photos avec des URL signées.
-- ════════════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos-articles', 'photos-articles', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

create policy photos_articles_select on storage.objects
  for select to authenticated
  using (bucket_id = 'photos-articles'
         and (storage.foldername(name))[1] = (select private.ma_boutique())::text);

create policy photos_articles_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos-articles'
              and (storage.foldername(name))[1] = (select private.ma_boutique())::text);

create policy photos_articles_update on storage.objects
  for update to authenticated
  using (bucket_id = 'photos-articles'
         and (storage.foldername(name))[1] = (select private.ma_boutique())::text)
  with check (bucket_id = 'photos-articles'
              and (storage.foldername(name))[1] = (select private.ma_boutique())::text);

create policy photos_articles_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'photos-articles'
         and (storage.foldername(name))[1] = (select private.ma_boutique())::text);


-- ▼▼▼ 20261118090000_creer_commande.sql ▼▼▼

-- ════════════════════════════════════════════════════════════════════
--  Vally Business — module Ventes : création d'une commande en un appel
--
--  Crée (si besoin) le client, la commande, ses lignes et un premier
--  paiement dans UNE transaction : si un article manque de stock, rien
--  n'est enregistré.
--  SECURITY INVOKER : RLS et déclencheurs s'appliquent normalement
--  (prix figés, contrôle du stock, conversion des devises).
-- ════════════════════════════════════════════════════════════════════

create function public.creer_commande(
  p_lignes           jsonb,                 -- [{"article_id", "quantite", "prix_vendu"}]
  p_client_id        uuid default null,     -- client existant
  p_client_nom       text default null,     -- ou nouveau client
  p_client_telephone text default null,
  p_date             date default current_date,
  p_note             text default null,
  p_paiement         jsonb default null     -- {"montant_saisi", "devise_saisie", "mode"}
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
      message = 'Ajoute au moins un article à la vente.',
      hint = 'commande_vide';
  end if;

  if v_client is null and nullif(btrim(p_client_nom), '') is not null then
    insert into public.clients (nom, telephone)
    values (btrim(p_client_nom), nullif(btrim(p_client_telephone), ''))
    returning id into v_client;
  end if;

  insert into public.commandes (client_id, date_commande, note)
  values (v_client, coalesce(p_date, current_date), nullif(btrim(p_note), ''))
  returning id into v_commande;

  -- prix_achat_snapshot / prix_habituel_snapshot : remplis par le déclencheur.
  for v_ligne in select * from jsonb_array_elements(p_lignes)
  loop
    insert into public.lignes_commande (commande_id, article_id, quantite, prix_vendu)
    values (v_commande,
            (v_ligne ->> 'article_id')::uuid,
            (v_ligne ->> 'quantite')::integer,
            (v_ligne ->> 'prix_vendu')::numeric);
  end loop;

  -- montant (devise de référence) : calculé par le déclencheur de conversion.
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

revoke all on function public.creer_commande(jsonb, uuid, text, text, date, text, jsonb) from public, anon;
grant execute on function public.creer_commande(jsonb, uuid, text, text, date, text, jsonb) to authenticated;


-- ▼▼▼ 20261118120000_refonte_ventes_commandes.sql ▼▼▼

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


-- ▼▼▼ 20261118150000_depenses_benefice_encaisse.sql ▼▼▼

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


-- ▼▼▼ 20261119090000_commandes_en_cours_non_comptees.sql ▼▼▼

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


-- ▼▼▼ 20261119120000_numeros_factures.sql ▼▼▼

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


-- ▼▼▼ 20261121090000_articles_des_ventes.sql ▼▼▼

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


-- ▼▼▼ 20261121120000_reapprovisionnement.sql ▼▼▼

-- ════════════════════════════════════════════════════════════════════
--  Vally Business — réapprovisionnement (racheter un article)
--
--  Chaque achat d'un article est gardé dans approvisionnements : le
--  premier (à la création de l'article), puis chaque rachat, avec sa
--  quantité, son prix unitaire (tous frais compris) et sa date.
--
--  • articles.quantite_achetee = total des pièces achetées ;
--  • articles.prix_achat = coût moyen pondéré des pièces en boutique,
--    recalculé à chaque rachat (c'est lui que les nouvelles ventes figent) ;
--  • v_stock.total_approvisionne = somme exacte des achats, même quand le
--    prix change d'un achat à l'autre ;
--  • dashboard_periode : l'argent investi compte à la date de chaque achat.
--
--  Racheter : public.reapprovisionner(). Se tromper : on annule le
--  dernier rachat (public.annuler_dernier_rachat()) et on le refait.
-- ════════════════════════════════════════════════════════════════════

create table public.approvisionnements (
  id               uuid primary key default gen_random_uuid(),
  boutique_id      uuid not null default private.ma_boutique()
                     references public.boutiques (id) on delete cascade,
  user_id          uuid default auth.uid() references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  article_id       uuid not null,
  date_appro       date not null default current_date,
  quantite         integer not null check (quantite > 0),
  -- Prix unitaire TOUS FRAIS COMPRIS, dans la devise de référence.
  prix_achat       numeric(14, 2) not null check (prix_achat >= 0),
  fournisseur      text,
  -- Coût moyen de l'article juste avant ce rachat (null : premier achat).
  -- Sert à revenir en arrière si on annule le rachat.
  prix_moyen_avant numeric(14, 2) check (prix_moyen_avant is null or prix_moyen_avant >= 0),
  -- Montant tel que saisi (USD ou CDF) et taux utilisé, pour l'affichage.
  devise_saisie    text check (devise_saisie is null or devise_saisie in ('CDF', 'USD')),
  montant_saisi    numeric(14, 2),
  taux_change      numeric(14, 4),
  constraint approvisionnements_article_fk foreign key (article_id, boutique_id)
    references public.articles (id, boutique_id) on delete cascade
);
comment on table public.approvisionnements is
  'Achats d''un article : le premier, puis chaque rachat. Écrit uniquement par les règles de la base.';
create index approvisionnements_article_idx on public.approvisionnements (article_id, created_at);
create index approvisionnements_boutique_date_idx on public.approvisionnements (boutique_id, date_appro);
create index approvisionnements_user_id_idx on public.approvisionnements (user_id);

-- Lecture seule pour l'appli : l'historique s'écrit par les fonctions ci-dessous.
alter table public.approvisionnements enable row level security;
revoke all on public.approvisionnements from anon, authenticated;
grant select on public.approvisionnements to authenticated;
create policy approvisionnements_lecture on public.approvisionnements
  for select to authenticated
  using (boutique_id = (select private.ma_boutique()));

-- Les articles déjà créés : leur achat devient le premier de l'historique.
insert into public.approvisionnements
  (boutique_id, user_id, created_at, article_id, date_appro, quantite, prix_achat, fournisseur)
select a.boutique_id, a.user_id, a.created_at, a.id, a.date_appro,
       a.quantite_achetee, a.prix_achat, a.fournisseur
from public.articles a;

-- ─── L'article et son historique restent d'accord ───────────────────
--  • création : le premier achat est noté ;
--  • article jamais racheté : le corriger corrige son unique achat ;
--  • article déjà racheté : quantité et prix ne se corrigent plus à la
--    main (on annule le dernier rachat et on le refait).
create function private.tg_articles_achats()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nb integer;
begin
  if tg_op = 'INSERT' then
    insert into public.approvisionnements
      (boutique_id, user_id, created_at, article_id, date_appro, quantite, prix_achat, fournisseur)
    values
      (new.boutique_id, new.user_id, new.created_at, new.id, new.date_appro,
       new.quantite_achetee, new.prix_achat, new.fournisseur);
    return null;
  end if;

  -- Rachat ou annulation : ces fonctions tiennent l'historique elles-mêmes.
  if coalesce(current_setting('vally.operation_stock', true), '') = 'oui' then
    return null;
  end if;

  if (new.quantite_achetee, new.prix_achat, new.date_appro, new.fournisseur)
     is not distinct from (old.quantite_achetee, old.prix_achat, old.date_appro, old.fournisseur) then
    return null;
  end if;

  select count(*) into v_nb from public.approvisionnements where article_id = new.id;
  if v_nb <= 1 then
    update public.approvisionnements
       set quantite = new.quantite_achetee,
           prix_achat = new.prix_achat,
           date_appro = new.date_appro,
           fournisseur = new.fournisseur
     where article_id = new.id;
    if not found then
      insert into public.approvisionnements
        (boutique_id, user_id, article_id, date_appro, quantite, prix_achat, fournisseur)
      values
        (new.boutique_id, new.user_id, new.id, new.date_appro,
         new.quantite_achetee, new.prix_achat, new.fournisseur);
    end if;
  elsif new.quantite_achetee <> old.quantite_achetee or new.prix_achat <> old.prix_achat then
    raise exception using
      message = 'Cet article a déjà été racheté : pour corriger la quantité ou le prix, '
                'annule le dernier rachat puis refais-le.',
      hint = 'article_rachete';
  end if;
  return null;
end;
$$;

revoke all on function private.tg_articles_achats() from public, anon, authenticated;

create trigger articles_achats
  after insert or update on public.articles
  for each row execute function private.tg_articles_achats();

-- ─── Racheter un article ────────────────────────────────────────────
--  Le prix est saisi en CDF ou en USD (converti au taux de la boutique).
--  Le nouveau coût moyen = (pièces encore en boutique × ancien coût
--  + pièces rachetées × nouveau prix) ÷ total des pièces en boutique.
--  Retourne ce nouveau coût moyen.
create function public.reapprovisionner(
  p_article       uuid,
  p_quantite      integer,
  p_prix_saisi    numeric,
  p_devise_saisie text,
  p_date          date default current_date,
  p_fournisseur   text default null
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_boutique uuid := private.exiger_boutique();
  v_article  public.articles%rowtype;
  v_devise   text;
  v_taux     numeric;
  v_prix     numeric;
  v_restant  integer;
  v_cmup     numeric;
  v_date     date := coalesce(p_date, current_date);
begin
  if p_quantite is null or p_quantite <= 0 then
    raise exception using message = 'Saisis au moins 1 pièce.', hint = 'quantite_invalide';
  end if;
  if p_prix_saisi is null or p_prix_saisi < 0 then
    raise exception using message = 'Le prix d''achat ne peut pas être négatif.', hint = 'prix_invalide';
  end if;
  if p_devise_saisie is null or p_devise_saisie not in ('CDF', 'USD') then
    raise exception using message = 'Choisis la devise : CDF ou USD.', hint = 'devise_invalide';
  end if;

  select b.devise_reference, b.taux_usd_cdf into v_devise, v_taux
  from public.boutiques b
  where b.id = v_boutique;

  -- Verrou : un rachat et une vente simultanés voient le même stock.
  select a.* into v_article
  from public.articles a
  where a.id = p_article and a.boutique_id = v_boutique
  for update;
  if not found then
    raise exception using message = 'Article introuvable.', hint = 'article_introuvable';
  end if;

  v_prix := case
    when p_devise_saisie = v_devise then p_prix_saisi
    when p_devise_saisie = 'USD'    then round(p_prix_saisi * v_taux, 2)
    else                                 round(p_prix_saisi / v_taux, 2)
  end;
  v_restant := greatest(v_article.quantite_achetee - private.quantite_vendue(p_article), 0);
  v_cmup := round((v_restant * v_article.prix_achat + p_quantite * v_prix) / (v_restant + p_quantite), 2);

  insert into public.approvisionnements
    (boutique_id, user_id, article_id, date_appro, quantite, prix_achat, fournisseur,
     prix_moyen_avant, devise_saisie, montant_saisi, taux_change)
  values
    (v_boutique, (select auth.uid()), p_article, v_date, p_quantite, v_prix,
     coalesce(nullif(btrim(p_fournisseur), ''), v_article.fournisseur),
     v_article.prix_achat, p_devise_saisie, p_prix_saisi,
     case when p_devise_saisie = v_devise then null else v_taux end);

  perform set_config('vally.operation_stock', 'oui', true);
  update public.articles
     set quantite_achetee = quantite_achetee + p_quantite,
         prix_achat = v_cmup,
         date_appro = greatest(date_appro, v_date),
         fournisseur = coalesce(nullif(btrim(p_fournisseur), ''), fournisseur)
   where id = p_article;
  perform set_config('vally.operation_stock', '', true);

  return v_cmup;
end;
$$;

-- ─── Annuler le dernier rachat (erreur de saisie) ───────────────────
--  Seul le plus récent se défait, pour retrouver exactement le coût
--  moyen d'avant. Impossible si ses pièces sont déjà vendues.
create function public.annuler_dernier_rachat(p_article uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_boutique uuid := private.exiger_boutique();
  v_article  public.articles%rowtype;
  v_achat    public.approvisionnements%rowtype;
begin
  select a.* into v_article
  from public.articles a
  where a.id = p_article and a.boutique_id = v_boutique
  for update;
  if not found then
    raise exception using message = 'Article introuvable.', hint = 'article_introuvable';
  end if;

  select x.* into v_achat
  from public.approvisionnements x
  where x.article_id = p_article
  order by x.created_at desc, x.id desc
  limit 1;
  if not found or v_achat.prix_moyen_avant is null then
    raise exception using message = 'Il n''y a pas de rachat à annuler pour cet article.', hint = 'aucun_rachat';
  end if;

  if v_article.quantite_achetee - v_achat.quantite < private.quantite_vendue(p_article) then
    raise exception using
      message = 'Impossible d''annuler ce rachat : des pièces qui en viennent sont déjà vendues ou réservées.',
      hint = 'quantite_sous_vendu';
  end if;

  perform set_config('vally.operation_stock', 'oui', true);
  update public.articles
     set quantite_achetee = quantite_achetee - v_achat.quantite,
         prix_achat = v_achat.prix_moyen_avant,
         date_appro = coalesce((select max(x.date_appro)
                                  from public.approvisionnements x
                                 where x.article_id = p_article and x.id <> v_achat.id),
                               date_appro)
   where id = p_article;
  delete from public.approvisionnements where id = v_achat.id;
  perform set_config('vally.operation_stock', '', true);
end;
$$;

revoke all on function public.reapprovisionner(uuid, integer, numeric, text, date, text) from public, anon;
revoke all on function public.annuler_dernier_rachat(uuid) from public, anon;
grant execute on function public.reapprovisionner(uuid, integer, numeric, text, date, text) to authenticated;
grant execute on function public.annuler_dernier_rachat(uuid) to authenticated;

-- ─── v_stock : investi = somme des achats ; nb_achats ajouté en fin ──

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
       coalesce(ach.nb, 1)                                              as nb_achats
from public.articles a
left join vendu v    on v.article_id = a.id
left join achats ach on ach.article_id = a.id;

-- ─── Statistiques : l'argent investi compte à la date de chaque achat ─

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
    (select coalesce(sum(ap.quantite * ap.prix_achat), 0)
       from public.approvisionnements ap
      where ap.date_appro between p_debut and p_fin),
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

commit;
