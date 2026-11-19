import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/placeholder_photo.dart';
import 'test_accounts.dart';

/// Auswahl der Test-Konten auf der Anmeldeseite: ein Tipp genügt.
class TestAccountPicker extends StatelessWidget {
  const TestAccountPicker({
    super.key,
    required this.onPick,
    this.busyEmail,
    this.accounts = testAccounts,
  });

  final ValueChanged<TestAccount> onPick;

  /// Konto, das gerade angemeldet wird (zeigt einen Ladekreis).
  final String? busyEmail;

  final List<TestAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final women = accounts.where((a) => a.isWoman).toList();
    final men = accounts.where((a) => !a.isWoman).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: LovelColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LovelColors.slate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, color: LovelColors.umber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Test-Accounts',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: LovelColors.umber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Antippen zum Anmelden. Test-Accounts sehen nur einander.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final row in [women, men])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (final a in row)
                    Expanded(
                      child: _AccountTile(
                        account: a,
                        busy: busyEmail == a.email,
                        enabled: busyEmail == null,
                        onTap: () => onPick(a),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final TestAccount account;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Als ${account.name} anmelden',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              SizedBox.square(
                dimension: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipOval(child: PlaceholderPhoto(art: account.portrait)),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: LovelColors.cream,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${account.name}, ${account.age}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
