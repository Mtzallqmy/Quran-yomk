import 'package:flutter/material.dart';

import '../navigation.dart';
import 'reciters.dart';

/// The existing catalog and reciter details remain the source of playback.
class ListenPage extends StatelessWidget {
  const ListenPage({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'القراء والمصاحف الصوتية',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'قوائم التشغيل',
              icon: const Icon(Icons.queue_music),
              onPressed: () =>
                  Navigator.pushNamed(context, MobileRoutes.playlists),
            ),
          ],
        ),
      ),
      const Expanded(child: RecitersPage()),
    ],
  );
}
