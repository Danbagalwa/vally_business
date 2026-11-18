import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/elements.dart';
import '../../../../theme/app_theme.dart';
import '../../data/tableau_de_bord_repository.dart';
import '../../domain/periode.dart';

/// Filtres de période, sur une ligne au-dessus des indicateurs.
class SelecteurPeriode extends ConsumerWidget {
  const SelecteurPeriode({super.key});

  Future<void> _choisirDates(BuildContext context, WidgetRef ref) async {
    final actuelle = ref.read(periodeProvider);
    final maintenant = DateTime.now();
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(maintenant.year, maintenant.month, maintenant.day),
      initialDateRange: actuelle.fin.isAfter(maintenant)
          ? null
          : DateTimeRange(start: actuelle.debut, end: actuelle.fin),
      helpText: 'Choisis une période',
      saveText: 'Valider',
    );
    if (plage != null) {
      ref
          .read(periodeProvider.notifier)
          .choisir(Periode.personnalisee(plage.start, plage.end));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periode = ref.watch(periodeProvider);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: VallySpace.s4),
        children: [
          for (final type in TypePeriode.values)
            Padding(
              padding: const EdgeInsets.only(right: VallySpace.s2),
              child: FiltrePastille(
                libelle: type.libelle,
                icone: type == TypePeriode.personnalisee ? Icons.date_range : null,
                actif: periode.type == type,
                onTap: () => type == TypePeriode.personnalisee
                    ? _choisirDates(context, ref)
                    : ref.read(periodeProvider.notifier).choisir(Periode.de(type)),
              ),
            ),
        ],
      ),
    );
  }
}
