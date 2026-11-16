# Vally Business

Application mobile (iOS et Android) de gestion d'une boutique de vêtements : stock, commandes, ventes, bénéfices et, séparément, les dépenses personnelles.

> *Ton stock, tes ventes et ton argent, au même endroit.*

- **Technologie mobile** : Flutter
- **Backend / base de données** : Supabase (PostgreSQL + Auth + Row Level Security)

---

## 1. Objectifs

1. Suivre les articles approvisionnés et connaître le **montant total investi**.
2. Suivre les **commandes et les ventes**, y compris les paiements en plusieurs fois.
3. Connaître le **bénéfice réel** et ce que le stock a coûté.
4. Suivre les **dépenses** (entrées et sorties d'argent) et le **flux de trésorerie**, sans lien avec les ventes.

---

## 2. Modules

### 2.1 Approvisionnement / Stock

Chaque article enregistré contient :

| Champ | Description |
|---|---|
| Nom | Ex. : « Robe pagne fleurie » |
| Catégorie | Robe, pantalon, chemise, chaussures… |
| Taille | S, M, L, 40, 42… |
| Couleur | Facultatif |
| Quantité achetée | Nombre de pièces |
| **Prix d'achat unitaire** | **Tous frais compris** (transport, douane, emballage inclus) |
| Prix de vente habituel | Prix de référence, facultatif, modifiable à la vente |
| Fournisseur | Facultatif |
| Date d'approvisionnement | |
| Photo | Facultatif |

**Calculs automatiques**
- Total approvisionné = Σ (quantité achetée × prix d'achat)
- Quantité restante = quantité achetée − quantité vendue
- Valeur du stock restant = Σ (quantité restante × prix d'achat)

### 2.2 Commandes et ventes

Une commande contient :
- Le client (nom, téléphone)
- La date
- Une ou plusieurs **lignes de commande** (article, quantité, prix réellement vendu)
- Un ou plusieurs **paiements**

**Prix de vente variable**
- À l'ajout d'un article, le *prix de vente habituel* est pré-rempli, mais **modifiable**.
- Le prix réellement pratiqué est enregistré sur la ligne de commande : c'est lui qui sert aux calculs.
- Ça gère aussi bien les ventes **au-dessus** du prix habituel que les **remises**.
- Si le prix habituel d'un article change, les anciennes ventes ne sont pas modifiées.
- L'appli affiche l'écart : « +5 000 au-dessus du prix habituel » / « −2 000 de remise ».

**Paiements partiels**
- Une commande peut recevoir plusieurs versements (avance, puis solde), chacun avec un montant, une date et un mode (espèces, mobile money…).
- Statut calculé automatiquement :
  - `non_payee` : aucun versement
  - `partiellement_payee` : versé < total
  - `soldee` : versé ≥ total
- Affichage du **reste à payer**.
- Statut de livraison séparé : `en_attente`, `livree`, `annulee`.

**Stock**
- Le stock diminue à la validation de la commande.
- Une commande annulée remet les quantités en stock.

**Calculs**
- Total commande = Σ (quantité × prix vendu)
- Coût de la commande = Σ (quantité × prix d'achat)
- **Bénéfice commande = total commande − coût**
- Écart vs prix habituel = Σ (prix vendu − prix habituel) × quantité

### 2.3 Tableau de bord (boutique)

Filtrable par période (mois, année, personnalisée) :

- Total approvisionné
- Total vendu (chiffre d'affaires)
- Total encaissé (argent réellement reçu)
- Total restant dû par les clients
- **Bénéfice réalisé** (sur les ventes)
- Bénéfice déjà versé vers *Mes dépenses*, et bénéfice disponible
- Valeur du stock restant
- Gain supplémentaire (ventes au-dessus du prix habituel) / coût des remises
- Articles les plus vendus / articles qui ne partent pas

### 2.4 Mes dépenses (séparé de la boutique)

Mouvements d'argent :

| Champ | Description |
|---|---|
| Type | `entree` ou `sortie` |
| Montant | |
| Catégorie | Loyer, nourriture, transport, salaire, autre… |
| Date | |
| Note | Facultatif |
| Source | `manuel` ou `boutique` (versement de bénéfice) |

**Affichage**
- Solde actuel = Σ entrées − Σ sorties
- Flux par mois (entrées, sorties, solde)
- Répartition des sorties par catégorie

**Bouton « Me verser un bénéfice »**
- Crée une **entrée** dans *Mes dépenses* avec la source `boutique`.
- Le montant est déduit du *bénéfice disponible* dans le tableau de bord boutique.
- Les deux parties restent séparées, mais on voit ce que la boutique rapporte réellement.

---

## 3. Identité visuelle

### Logo
Une **étiquette de prix** rose avec un « V » blanc et sa ficelle rose vif. Le nom s'écrit **Vally Business** : « Vally » en DM Serif Display, « BUSINESS » en Inter capitales espacées, en rose.

### Couleurs

| Nom | Clair | Sombre | Usage |
|---|---|---|---|
| Rose (principal) | `#C2255C` | `#F06595` | Bouton principal, onglet actif, bouton « + » |
| Rose profond | `#8F1D45` | `#FFB3CC` | Texte sur rose pâle |
| Rose pâle | `#FCE4EC` | `#4A2233` | Badges, fonds doux, fond de l'icône |
| Rose vif | `#F783AC` | `#F783AC` | Décoration et graphiques uniquement |
| Fond | `#FFF7FA` | `#1E1218` | Fond des écrans |
| Cartes | `#FFFFFF` | `#2A1A22` | Cartes, champs, barre d'onglets |
| Texte | `#2A1520` | `#FBEFF4` | Texte principal, montants |
| Texte secondaire | `#6E5562` | `#C9AEBB` | Dates, libellés |
| Bénéfice | `#1F7A55` | `#5BC39A` | Entrées d'argent, commande soldée (toujours avec « + ») |
| Attention | `#A84B0C` | `#F2A541` | Sorties, reste à payer, stock faible (toujours avec « − » ou une icône) |

Tous les textes respectent un contraste d'au moins 4,5:1, en clair comme en sombre.

### Typographie et formes
- **DM Serif Display** : grands montants du tableau de bord, titres d'écran.
- **Inter** : tout le reste ; chiffres à largeur fixe pour les montants.
- Polices incluses dans l'appli (fonctionne sans internet), licence SIL OFL 1.1.
- Grille de 4 px (4 / 8 / 16 / 24). Coins : 8 px (champs, badges), 16 px (cartes, boutons), pilule (filtres, bouton « + »).

### Ton
Tutoiement, phrases courtes, verbes d'action (« Ajouter un article »). Pas d'emoji ni de points d'exclamation dans l'interface.

### Ressources
- **Charte graphique** (couleurs, typo, logos) : artifact « Vally Business ».
- **Kit mobile** `vally_business_kit.zip` : icônes Android/iOS (adaptative, monochrome, notification), écran de démarrage clair/sombre, polices, thème Flutter `app_theme.dart`, configuration `flutter_launcher_icons` + `flutter_native_splash`, visuels Google Play et App Store.

## 4. Navigation (Flutter)

Barre d'onglets en bas (fond blanc, onglet actif sur rose pâle), 4 onglets :

1. **Stock** : liste des articles, recherche, filtre par catégorie, ajout/modification
2. **Ventes** : liste des commandes (filtre par statut), création de commande, ajout de paiement
3. **Tableau de bord** : indicateurs boutique + graphiques
4. **Dépenses** : solde, liste des mouvements, ajout entrée/sortie, flux mensuel

---

## 5. Modèle de données (Supabase)

Toutes les tables ont `id` (uuid), `user_id` (référence `auth.users`) et `created_at`.

### `articles`
| Colonne | Type |
|---|---|
| nom | text |
| categorie | text |
| taille | text |
| couleur | text, null |
| quantite_achetee | integer |
| prix_achat | numeric (tous frais compris) |
| prix_vente_habituel | numeric, null |
| fournisseur | text, null |
| date_appro | date |
| photo_url | text, null |

### `clients`
| Colonne | Type |
|---|---|
| nom | text |
| telephone | text, null |

### `commandes`
| Colonne | Type |
|---|---|
| client_id | uuid → clients, null |
| date_commande | date |
| statut_livraison | text (`en_attente`, `livree`, `annulee`) |
| note | text, null |

### `lignes_commande`
| Colonne | Type |
|---|---|
| commande_id | uuid → commandes |
| article_id | uuid → articles |
| quantite | integer |
| prix_vendu | numeric (prix réellement pratiqué) |
| prix_achat_snapshot | numeric (copie du prix d'achat au moment de la vente) |
| prix_habituel_snapshot | numeric, null (copie du prix habituel au moment de la vente) |

> Les « snapshots » figent les prix au moment de la vente : modifier un article plus tard ne fausse pas les bénéfices passés.

### `paiements`
| Colonne | Type |
|---|---|
| commande_id | uuid → commandes |
| montant | numeric |
| date_paiement | date |
| mode | text (`especes`, `mobile_money`, `virement`, `autre`) |

### `mouvements` (Mes dépenses)
| Colonne | Type |
|---|---|
| type | text (`entree`, `sortie`) |
| montant | numeric |
| categorie | text |
| date_mouvement | date |
| note | text, null |
| source | text (`manuel`, `boutique`) |

### Vues calculées (suggestion)
- `v_stock` : quantité restante et valeur du stock par article
- `v_commandes` : total, coût, bénéfice, total payé, reste à payer et statut de paiement par commande
- `v_dashboard` : indicateurs agrégés par période
- `v_flux_mensuel` : entrées / sorties / solde par mois

### Sécurité
- **Supabase Auth** (email + mot de passe ou téléphone OTP).
- **Row Level Security** activée sur toutes les tables : chaque utilisateur ne voit que ses propres données (`user_id = auth.uid()`).

---

## 6. Règles métier

1. Le prix d'achat inclut tous les frais : pas de champ de frais séparé.
2. Le prix de vente se fixe **à la vente**, pas sur l'article.
3. On ne peut pas vendre plus que la quantité restante en stock.
4. Une commande annulée remet son stock et sort du calcul des bénéfices.
5. *Mes dépenses* n'est **jamais** alimenté automatiquement par les ventes : seulement manuellement ou via « Me verser un bénéfice ».
6. Les montants sont stockés en `numeric`. La devise est configurable (ex. FCFA, EUR).

---

## 7. Stack technique Flutter (suggestion)

| Besoin | Package |
|---|---|
| Supabase | `supabase_flutter` |
| Gestion d'état | `riverpod` (ou `bloc`) |
| Navigation | `go_router` |
| Graphiques | `fl_chart` |
| Formatage montants/dates | `intl` |
| Photos | `image_picker` + Supabase Storage |
| Icône de l'appli | `flutter_launcher_icons` ^0.14.4 (dev) |
| Écran de démarrage | `flutter_native_splash` ^2.4.8 |
| Thème | `lib/theme/app_theme.dart` (fourni dans le kit) |

---

## 8. Étapes de réalisation

1. Créer le projet Supabase, les tables, les vues et les règles RLS
2. Initialiser le projet Flutter, installer le kit Vally Business (icônes, écran de démarrage, polices, thème), puis connecter Supabase + authentification
3. Module **Stock**
4. Module **Ventes** (commandes, lignes, paiements partiels)
5. **Tableau de bord**
6. Module **Mes dépenses** + bouton « Me verser un bénéfice »
7. Tests, puis publication App Store / Play Store (captures d'écran, descriptions, politique de confidentialité à préparer)

---

## 9. Décisions prises

- Nom : **Vally Business**
- Plateformes : iOS et Android, avec **Flutter**
- Backend : **Supabase**
- Prix d'achat : **tous frais compris**, un seul champ
- Prix de vente : fixé **à chaque vente** (au-dessus ou en dessous du prix habituel)
- Paiements : **en plusieurs fois** possibles
- Dépenses personnelles : **séparées** de la boutique, reliées seulement par « Me verser un bénéfice »
- Logo : **l'étiquette de prix**, palette rose

## 10. Points à décider

- Prix de vente habituel : obligatoire ou facultatif ? (actuellement : **facultatif**)
- Devise utilisée
- Un seul utilisateur, ou plusieurs (ex. un vendeur qui aide) ?
- Mode hors-ligne nécessaire ? (Supabase demande internet par défaut)
