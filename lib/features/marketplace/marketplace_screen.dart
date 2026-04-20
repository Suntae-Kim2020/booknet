import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/sale_bundle.dart';
import '../../providers.dart';

final myBundlesProvider = FutureProvider<List<SaleBundle>>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(bundleRepoProvider).myBundles();
});

class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundles = ref.watch(myBundlesProvider);
    final fmt = NumberFormat.decimalPattern();
    return Scaffold(
      appBar: AppBar(title: const Text('판매 꾸러미')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bundle/edit'),
        icon: const Icon(Icons.add),
        label: const Text('꾸러미 만들기'),
      ),
      body: bundles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('판매 꾸러미가 없습니다.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final b = list[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(b.title),
                  subtitle: Text('${b.books.length}권 · ${b.statusLabel}'),
                  trailing: Text('${fmt.format(b.totalPriceWon)}원'),
                  onTap: () => context.push('/bundle/${b.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
