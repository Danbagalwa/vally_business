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
