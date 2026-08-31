import 'package:flutter/material.dart';

import 'radio.dart';

class RadioCategoryPage extends StatelessWidget {
  const RadioCategoryPage({
    super.key,
    required this.category,
    required this.title,
  });

  final String category;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: RadioPage(initialCategory: category),
      );
}
