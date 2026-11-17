import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Bild aus einer fremden Datenbank (RAWG, Spotify). Im Browser notfalls als
/// HTML-Bild, weil nicht jedes CDN CORS erlaubt. Ohne URL/bei Fehlern ein
/// ruhiger Platzhalter mit Anfangsbuchstaben.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    required this.fallbackLabel,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final String fallbackLabel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null) return _Fallback(label: fallbackLabel);
    return Image.network(
      u,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, _, _) => _Fallback(label: fallbackLabel),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const ColoredBox(color: LovelColors.mist),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.label});

  final String label;

  static const _colors = [
    LovelColors.slate,
    LovelColors.terracotta,
    LovelColors.umber,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[label.hashCode.abs() % _colors.length];
    return ColoredBox(
      color: color,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              color: LovelColors.cream,
              fontSize: 16,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }
}
