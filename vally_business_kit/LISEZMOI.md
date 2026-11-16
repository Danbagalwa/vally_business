# Vally Business — Kit pour l'application mobile (Android et iOS)

Tout ce qu'il faut pour habiller l'application Flutter **Vally Business** : icônes, écran de démarrage, polices, thème, logos et visuels pour les stores.

---

## Contenu du kit

```
vally_business_kit/
├── flutter/                      ← à copier à la racine de ton projet Flutter
│   ├── assets/icon/              icône 1024, avant-plan adaptatif, monochrome Android 13+
│   ├── assets/splash/            logo de démarrage, version Android 12, signature claire/sombre
│   ├── assets/fonts/             Inter + DM Serif Display (+ licences OFL)
│   ├── lib/theme/app_theme.dart  thème clair/sombre aux couleurs de la charte
│   └── pubspec_a_ajouter.yaml    configuration à fusionner dans pubspec.yaml
├── android/res/                  icônes Android déjà prêtes (si tu ne veux pas générer)
│   ├── mipmap-*/                 ic_launcher + ic_launcher_round (48 → 192 px)
│   ├── drawable-*/               ic_stat_vally : icône de notification (blanche)
│   └── values/                   couleur de fond de l'icône adaptative
├── ios/AppIcon.appiconset/       icône iOS 1024 + Contents.json (Xcode 14+)
├── stores/
│   ├── google-play/              icône 512×512, image de présentation 1024×500
│   └── app-store/                icône 1024×1024 sans transparence
├── logos/                        logo horizontal clair/sombre, symbole, icône (SVG + PNG)
└── sources/                      fichiers SVG d'origine, pour retoucher
```

---

## Installation dans Flutter (10 minutes)

1. **Copie** le contenu du dossier `flutter/` à la racine de ton projet (les dossiers `assets/` et `lib/theme/` viennent se poser à côté de ton `lib/`).
2. **Fusionne** `pubspec_a_ajouter.yaml` dans ton `pubspec.yaml` : dépendances, `assets`, `fonts`, et les deux blocs `flutter_launcher_icons` et `flutter_native_splash`.
3. Dans un terminal, à la racine du projet :
   ```bash
   flutter pub get
   dart run flutter_launcher_icons
   dart run flutter_native_splash:create
   ```
4. **Branche le thème** dans `main.dart` :
   ```dart
   import 'theme/app_theme.dart';

   MaterialApp(
     title: 'Vally Business',
     theme: VallyTheme.light,
     darkTheme: VallyTheme.dark,
     themeMode: ThemeMode.system,
     home: ...,
   );
   ```
5. **Lance** l'appli sur un téléphone (`flutter run`) et vérifie l'icône et l'écran de démarrage, en mode clair et en mode sombre.

> Conseil : fais un commit Git avant l'étape 3, pour voir exactement ce que les deux outils ont modifié.

---

## Nom de l'application

Le nom affiché sous l'icône est **Vally Business**. Il tient sur l'écran d'accueil iPhone et Android.

- **Android** : `android/app/src/main/AndroidManifest.xml` → `android:label="Vally Business"`
- **iOS** : `ios/Runner/Info.plist` → `CFBundleDisplayName` = `Vally Business`

---

## Icône de notification (Android)

Quand l'appli enverra des notifications (rappel de paiement, stock faible…), Android exige une icône **blanche sur fond transparent**.

- Copie les dossiers `android/res/drawable-*/` dans `android/app/src/main/res/`.
- Utilise le nom `ic_stat_vally` (par exemple avec `flutter_local_notifications` : `AndroidInitializationSettings('ic_stat_vally')`).

---

## Pour les stores

| Store | Fichier | Taille | À savoir |
|---|---|---|---|
| Google Play | `stores/google-play/play-store-icon-512.png` | 512×512 | Carré plein, Google arrondit lui-même |
| Google Play | `stores/google-play/feature-graphic-1024x500.png` | 1024×500 | Image de présentation, obligatoire |
| App Store | `stores/app-store/app-store-icon-1024.png` | 1024×1024 | Sans transparence, sans coins arrondis |

**Il te restera à faire toi-même** : les captures d'écran de l'appli une fois terminée (Google Play : au moins 2 captures de téléphone ; App Store : captures iPhone 6,9" ou 6,5"), la description courte et longue, et la politique de confidentialité (obligatoire sur les deux stores). Je peux t'aider à les préparer le moment venu.

---

## Couleurs de référence

| Nom | Clair | Sombre | Usage |
|---|---|---|---|
| Rose (principal) | `#C2255C` | `#F06595` | Boutons principaux, onglet actif, bouton « + » |
| Rose profond | `#8F1D45` | `#FFB3CC` | Texte sur rose pâle |
| Rose pâle | `#FCE4EC` | `#4A2233` | Badges, fonds doux, fond de l'icône |
| Rose vif | `#F783AC` | `#F783AC` | Décoration et graphiques uniquement |
| Fond | `#FFF7FA` | `#1E1218` | Fond des écrans, écran de démarrage |
| Cartes | `#FFFFFF` | `#2A1A22` | Cartes, champs, barre d'onglets |
| Texte | `#2A1520` | `#FBEFF4` | Texte principal et montants |
| Texte secondaire | `#6E5562` | `#C9AEBB` | Dates, libellés |
| Bénéfice | `#1F7A55` | `#5BC39A` | Argent qui entre, commande soldée (toujours avec « + ») |
| Attention | `#A84B0C` | `#F2A541` | Sorties, reste à payer, stock faible (toujours avec « − » ou une icône) |

Dans le code : `Theme.of(context).colorScheme.primary` pour le rose, et `Theme.of(context).extension<VallyColors>()!.benefice` / `.attention` pour l'argent.

---

## Polices

- **DM Serif Display** : grands montants du tableau de bord et titres d'écran.
- **Inter** : tout le reste. Les montants utilisent les chiffres à largeur fixe, pour rester alignés.

Les polices sont **incluses dans l'appli** (pas de téléchargement au lancement) : l'appli marche aussi sans internet. Les deux sont sous licence libre SIL OFL 1.1 (fichiers de licence fournis), donc tu peux les utiliser dans une appli publiée.
