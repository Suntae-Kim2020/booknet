import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class BooknetApp extends ConsumerWidget {
  const BooknetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Booknet',
      debugShowCheckedModeBanner: false,
      theme: booknetLightTheme,
      darkTheme: booknetDarkTheme,
      routerConfig: router,
    );
  }
}
