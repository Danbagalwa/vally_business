import 'package:flutter_test/flutter_test.dart';

import 'package:vally_business/app.dart';
import 'package:vally_business/core/format/montant.dart';

void main() {
  testWidgets('Sans clés Supabase, l’appli explique comment la lancer',
      (tester) async {
    await tester.pumpWidget(const ConfigurationManquanteApp());
    expect(find.text('Configuration manquante'), findsOneWidget);
  });

  group('FormatMontant', () {
    test('CDF sans décimales, bénéfice avec « + »', () {
      expect(
        FormatMontant.formater(125000, Devise.cdf, sens: SensMontant.positif),
        '+ 125 000 CDF',
      );
    });

    test('USD avec 2 décimales, sortie avec « − »', () {
      expect(
        FormatMontant.formater(12.5, Devise.usd, sens: SensMontant.negatif),
        '− 12,50 USD',
      );
    });

    test('Conversion USD ↔ CDF', () {
      expect(
        FormatMontant.convertir(10,
            de: Devise.usd, vers: Devise.cdf, tauxUsdVersCdf: 2800),
        28000,
      );
      expect(
        FormatMontant.convertir(28000,
            de: Devise.cdf, vers: Devise.usd, tauxUsdVersCdf: 2800),
        10,
      );
    });
  });
}
