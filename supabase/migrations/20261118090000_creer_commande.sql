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
