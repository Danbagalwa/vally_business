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
