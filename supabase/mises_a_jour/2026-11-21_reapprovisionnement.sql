-- ════════════════════════════════════════════════════════════════════
--  Vally Business — mise à jour du 21/11/2026 : réapprovisionnement
--
--  À coller dans Supabase : SQL Editor → New query → Run.
--  À exécuter UNE FOIS, après 2026-11-21_articles_des_ventes.sql.
--  Tes articles existants gardent leurs chiffres : leur achat devient le
--  premier de leur historique. Aucune vente n'est modifiée.
--  Tout s'exécute dans une transaction : en cas d'erreur, rien ne change.
-- ════════════════════════════════════════════════════════════════════

begin;

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
