import 'package:flutter/material.dart';

import 'l10n.dart';
import 'theme.dart';

class LoadingPane extends StatelessWidget {
  const LoadingPane({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Semantics(
      label: 'جارٍ التحميل',
      child: SizedBox.square(
        dimension: 34,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    ),
  );
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TarteelTokens.spaceLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(TarteelTokens.radiusMd),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(TarteelTokens.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.inbox_outlined,
                    size: 38,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: TarteelTokens.spaceSm),
                  Text(
                    message ?? context.l10n.noData,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(TarteelTokens.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(context.l10n.offlineMessage, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retry),
          ),
        ],
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 26, 16, 10),
    child: Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    this.url,
    this.size = 52,
    this.icon = Icons.graphic_eq,
  });

  final String? url;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TarteelTokens.radiusSm),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Icon(icon),
    );
    final value = url;
    if (value == null || value.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(TarteelTokens.radiusSm),
      child: Image.network(
        value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
