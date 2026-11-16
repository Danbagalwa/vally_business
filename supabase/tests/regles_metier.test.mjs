import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Teste les migrations dans un Postgres en mémoire (PGlite), avec une
// imitation minimale de Supabase (auth.users, auth.uid(), storage, rôles).
// Aucun accès au projet Supabase distant.
//   cd supabase\tests ; npm install ; npm test
const dir = process.argv[2] ?? fileURLToPath(new URL('../migrations', import.meta.url));
const db = new PGlite();

// ── Stand-in minimal de Supabase (auth, storage, rôles) ──
await db.exec(`
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
  create schema auth; create schema storage;
  create table auth.users (id uuid primary key, email varchar(255));
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema auth, storage, public to anon, authenticated;
  grant execute on function auth.uid() to anon, authenticated;
  create table storage.buckets (id text primary key, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text);
  alter table storage.objects enable row level security;
  grant all on storage.objects to authenticated;
  create function storage.foldername(name text) returns text[] language sql immutable as
    $$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'),1)-1] $$;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
  insert into auth.users values
    ('aaaaaaaa-0000-0000-0000-000000000001', 'admin@exemple.cd'),
    ('bbbbbbbb-0000-0000-0000-000000000002', 'aide@exemple.cd'),
    ('cccccccc-0000-0000-0000-000000000003', 'autre@exemple.cd');
`);

for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) {
  try {
    await db.exec(fs.readFileSync(path.join(dir, f), 'utf8'));
    console.log('✔ migration', f);
  } catch (e) {
    console.log('✘ migration', f, '→', e.message);
    process.exit(1);
  }
}

const A = 'aaaaaaaa-0000-0000-0000-000000000001';
const B = 'bbbbbbbb-0000-0000-0000-000000000002';
const C = 'cccccccc-0000-0000-0000-000000000003';
let ok = 0, ko = 0;

async function as(uid, sql, params = []) {
  await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false); set role ${uid ? 'authenticated' : 'anon'};`);
  try { return (await db.query(sql, params)).rows; } finally { await db.exec('reset role;'); }
}
async function expectOk(nom, fn, check) {
  try {
    const r = await fn();
    if (check && !check(r)) throw new Error('résultat inattendu : ' + JSON.stringify(r));
    ok++; console.log('  ✔', nom);
    return r;
  } catch (e) { ko++; console.log('  ✘', nom, '→', e.message); }
}
async function expectErr(nom, fn, motif) {
  try { const r = await fn(); ko++; console.log('  ✘', nom, '→ aucune erreur', JSON.stringify(r)); }
  catch (e) {
    const txt = `${e.message} ${e.hint ?? ''}`;
    if (motif && !txt.includes(motif)) { ko++; console.log('  ✘', nom, '→ mauvaise erreur :', txt); }
    else { ok++; console.log('  ✔', nom, '→', e.message); }
  }
}

console.log('\nBoutique et membres');
await expectErr('sans boutique : pas d’insertion d’article', () => as(A,
  `insert into articles (nom, categorie, taille, quantite_achetee, prix_achat, prix_vente_habituel) values ('x','y','M',1,1,1)`));
await expectOk('A crée sa boutique (CDF, 1 USD = 2800 CDF)', () => as(A, `select creer_boutique('Vally', 'CDF', 2800) as id`));
await expectErr('A ne peut pas créer une 2e boutique', () => as(A, `select creer_boutique('Bis', 'CDF', 2800)`), 'deja_membre');
await expectOk('C crée une autre boutique', () => as(C, `select creer_boutique('Autre', 'USD', 2800)`));
await expectErr('ajout d’un email inconnu', () => as(A, `select ajouter_membre('inconnu@x.cd')`), 'compte_introuvable');
await expectErr('ajout d’un compte déjà dans une boutique', () => as(A, `select ajouter_membre('autre@exemple.cd')`), 'deja_membre');
await expectErr('impossible de changer la devise de référence', () => as(A, `update boutiques set devise_reference = 'USD'`), 'devise_non_modifiable');
await expectOk('changer le taux met à jour taux_maj_le', () => as(A, `update boutiques set taux_usd_cdf = 2800 returning taux_maj_le`), (r) => r.length === 1);

console.log('\nStock');
const [art] = await expectOk('A ajoute un article (5 pièces, achat 10 000, habituel 15 000)', () => as(A,
  `insert into articles (nom, categorie, taille, quantite_achetee, prix_achat, prix_vente_habituel)
   values ('Robe pagne fleurie', 'Robe', 'M', 5, 10000, 15000) returning id`));
await expectErr('quantité 0 refusée', () => as(A,
  `insert into articles (nom, categorie, taille, quantite_achetee, prix_achat, prix_vente_habituel) values ('x','y','M',0,1,1)`));
await expectErr('prix d’achat négatif refusé', () => as(A,
  `insert into articles (nom, categorie, taille, quantite_achetee, prix_achat, prix_vente_habituel) values ('x','y','M',1,-1,1)`));
await expectErr('prix habituel obligatoire', () => as(A,
  `insert into articles (nom, categorie, taille, quantite_achetee, prix_achat) values ('x','y','M',1,1)`));
await expectOk('v_stock : 5 restantes, 50 000 investis', () => as(A, `select * from v_stock`),
  (r) => r[0].quantite_restante === 5 && Number(r[0].total_approvisionne) === 50000);

console.log('\nVentes');
const [cli] = await as(A, `insert into clients (nom, telephone) values ('Mama Nsimba', '+243 81 000 0000') returning id`);
const [cmd1] = await as(A, `insert into commandes (client_id) values ($1) returning id`, [cli.id]);
await expectOk('ligne 3 × 17 000 (au-dessus du prix habituel), snapshots remplis par le serveur', () => as(A,
  `insert into lignes_commande (commande_id, article_id, quantite, prix_vendu, prix_achat_snapshot)
   values ($1, $2, 3, 17000, 1) returning prix_achat_snapshot, prix_habituel_snapshot`, [cmd1.id, art.id]),
  (r) => Number(r[0].prix_achat_snapshot) === 10000 && Number(r[0].prix_habituel_snapshot) === 15000);
const [cmd2] = await as(A, `insert into commandes default values returning id`);
await expectErr('vendre 3 de plus alors qu’il en reste 2', () => as(A,
  `insert into lignes_commande (commande_id, article_id, quantite, prix_vendu, prix_achat_snapshot) values ($1, $2, 3, 15000, 0)`,
  [cmd2.id, art.id]), 'stock_insuffisant');
await expectOk('vendre les 2 restantes avec remise (13 000)', () => as(A,
  `insert into lignes_commande (commande_id, article_id, quantite, prix_vendu, prix_achat_snapshot) values ($1, $2, 2, 13000, 0) returning id`,
  [cmd2.id, art.id]));
await expectErr('quantité achetée sous la quantité vendue', () => as(A, `update articles set quantite_achetee = 4`), 'quantite_sous_vendu');
await expectErr('supprimer un article vendu', () => as(A, `delete from articles where id = $1`, [art.id]));

console.log('\nPaiements (CDF et USD)');
await expectOk('commande 1 : non payée, total 51 000, bénéfice 21 000, gain +6 000', () => as(A,
  `select * from v_commandes where id = $1`, [cmd1.id]),
  (r) => r[0].statut_paiement === 'non_payee' && Number(r[0].total) === 51000 && Number(r[0].benefice) === 21000 && Number(r[0].gain_au_dessus) === 6000);
await expectOk('avance de 10 USD → 28 000 CDF au taux de la boutique', () => as(A,
  `insert into paiements (commande_id, montant_saisi, devise_saisie, montant, mode) values ($1, 10, 'USD', 1, 'mobile_money') returning montant, taux_change`, [cmd1.id]),
  (r) => Number(r[0].montant) === 28000 && Number(r[0].taux_change) === 2800);
await expectOk('partiellement payée, reste 23 000', () => as(A, `select * from v_commandes where id = $1`, [cmd1.id]),
  (r) => r[0].statut_paiement === 'partiellement_payee' && Number(r[0].reste_a_payer) === 23000);
await expectOk('solde de 23 000 CDF', () => as(A,
  `insert into paiements (commande_id, montant_saisi, devise_saisie, montant) values ($1, 23000, 'CDF', 0.01) returning montant`, [cmd1.id]),
  (r) => Number(r[0].montant) === 23000);
await expectOk('soldée, reste 0', () => as(A, `select * from v_commandes where id = $1`, [cmd1.id]),
  (r) => r[0].statut_paiement === 'soldee' && Number(r[0].reste_a_payer) === 0);
await expectErr('paiement de 0 refusé', () => as(A,
  `insert into paiements (commande_id, montant_saisi, devise_saisie, montant) values ($1, 0, 'CDF', 0)`, [cmd2.id]), 'montant_invalide');

console.log('\nAnnulation');
await expectOk('annuler la commande 2 remet 2 pièces en stock', async () => {
  await as(A, `update commandes set statut_livraison = 'annulee' where id = $1`, [cmd2.id]);
  return as(A, `select quantite_restante from v_stock`);
}, (r) => r[0].quantite_restante === 2);
await expectErr('paiement sur commande annulée', () => as(A,
  `insert into paiements (commande_id, montant_saisi, devise_saisie, montant) values ($1, 1000, 'CDF', 1)`, [cmd2.id]), 'commande_annulee');
await expectErr('ajouter une ligne à une commande annulée', () => as(A,
  `update lignes_commande set quantite = 1 where commande_id = $1`, [cmd2.id]), 'commande_annulee');
const [cmd3] = await as(A, `insert into commandes default values returning id`);
await as(A, `insert into lignes_commande (commande_id, article_id, quantite, prix_vendu, prix_achat_snapshot) values ($1, $2, 1, 15000, 0)`, [cmd3.id, art.id]);
await expectErr('réactiver la commande 2 sans stock suffisant', () => as(A,
  `update commandes set statut_livraison = 'en_attente' where id = $1`, [cmd2.id]), 'stock_insuffisant');

console.log('\nTableau de bord et Mes dépenses');
await expectOk('v_dashboard : bénéfice réalisé 26 000 (21 000 + 5 000), annulée exclue', () => as(A, `select * from v_dashboard`),
  (r) => Number(r[0].benefice_realise) === 26000 && Number(r[0].chiffre_affaires) === 66000 && Number(r[0].total_encaisse) === 51000);
await expectErr('l’appli ne peut pas créer une entrée « boutique » directement', () => as(A,
  `insert into mouvements (type, montant_saisi, devise_saisie, montant, categorie, source) values ('entree', 1000, 'CDF', 1, 'x', 'boutique')`));
await expectErr('verser plus que le bénéfice disponible', () => as(A, `select verser_benefice(30000, 'CDF')`), 'benefice_insuffisant');
await expectOk('me verser 5 USD (14 000 CDF)', () => as(A, `select verser_benefice(5, 'USD', null, 'Pour le loyer') as id`));
await expectOk('bénéfice versé 14 000, disponible 12 000', () => as(A, `select * from v_dashboard`),
  (r) => Number(r[0].benefice_verse) === 14000 && Number(r[0].benefice_disponible) === 12000);
await expectOk('sortie manuelle de 4 000 (loyer)', () => as(A,
  `insert into mouvements (type, montant_saisi, devise_saisie, montant, categorie) values ('sortie', 4000, 'CDF', 1, 'Loyer') returning montant`),
  (r) => Number(r[0].montant) === 4000);
await expectErr('modifier un versement « boutique »', async () => {
  const r = await as(A, `update mouvements set note = 'x' where source = 'boutique' returning id`);
  if (r.length === 0) throw new Error('aucune ligne modifiable (RLS)');
  return r;
});
await expectOk('v_flux_mensuel : +14 000 / −4 000, solde 10 000', () => as(A, `select * from v_flux_mensuel`),
  (r) => Number(r[0].entrees) === 14000 && Number(r[0].sorties) === 4000 && Number(r[0].solde_cumule) === 10000);
await expectOk('dashboard_periode sur l’année', () => as(A, `select * from dashboard_periode('2026-01-01', '2026-12-31')`),
  (r) => Number(r[0].benefice) === 26000 && Number(r[0].total_approvisionne) === 50000);
await expectOk('articles_vendus_periode', () => as(A, `select * from articles_vendus_periode('2026-01-01', '2026-12-31')`),
  (r) => r[0].quantite === 4);

console.log('\nIsolation et partage');
await expectOk('B (sans boutique) ne voit rien', () => as(B, `select * from v_stock`), (r) => r.length === 0);
await expectOk('C (autre boutique) ne voit rien de Vally', async () => [
  ...(await as(C, `select id from articles`)), ...(await as(C, `select id from mouvements`)), ...(await as(C, `select boutique_id from v_dashboard`))],
  (r) => r.length === 1 /* seulement sa propre ligne v_dashboard */);
await expectErr('C ne peut pas glisser une ligne dans une commande de Vally', () => as(C,
  `insert into lignes_commande (commande_id, article_id, quantite, prix_vendu, prix_achat_snapshot) values ($1, $2, 1, 1, 0)`, [cmd3.id, art.id]));
await expectErr('anon : aucun accès', () => as(null, `select * from articles`), 'permission');
await expectOk('A ajoute B par email', () => as(A, `select ajouter_membre('AIDE@exemple.cd ')`));
await expectOk('B voit maintenant le stock partagé et Mes dépenses', async () => [
  ...(await as(B, `select id from articles`)), ...(await as(B, `select id from mouvements`))], (r) => r.length === 3);
await expectOk('membres_boutique liste 2 comptes avec email', () => as(B, `select * from membres_boutique()`),
  (r) => r.length === 2 && r.some((m) => m.est_moi && m.email === 'aide@exemple.cd'));
await expectOk('A retire B', () => as(A, `select retirer_membre($1)`, [B]));
await expectErr('A ne peut pas se retirer (dernier membre)', () => as(A, `select retirer_membre($1)`, [A]), 'dernier_membre');
await expectOk('B ne voit plus rien', () => as(B, `select id from articles`), (r) => r.length === 0);

console.log('\nPhotos (Storage)');
const [{ boutique }] = await as(A, `select private.ma_boutique()::text as boutique`);
await expectOk('A dépose une photo dans le dossier de sa boutique', () => as(A,
  `insert into storage.objects (bucket_id, name) values ('photos-articles', $1) returning id`, [`${boutique}/robe.jpg`]));
await expectErr('C ne peut pas déposer dans le dossier de Vally', () => as(C,
  `insert into storage.objects (bucket_id, name) values ('photos-articles', $1)`, [`${boutique}/pirate.jpg`]));
await expectOk('C ne voit pas les photos de Vally', () => as(C, `select * from storage.objects`), (r) => r.length === 0);

console.log(`\n${ok} réussis, ${ko} échoués`);
process.exit(ko ? 1 : 0);
