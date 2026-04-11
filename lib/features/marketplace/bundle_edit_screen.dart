import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/bundle_book.dart';
import '../../models/sale_bundle.dart';
import '../../providers.dart';
import '../library/library_screen.dart';
import '../marketplace/marketplace_screen.dart';

class BundleEditScreen extends ConsumerStatefulWidget {
  const BundleEditScreen({super.key});

  @override
  ConsumerState<BundleEditScreen> createState() => _BundleEditScreenState();
}

class _BundleEditScreenState extends ConsumerState<BundleEditScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final Map<String, TextEditingController> _prices = {};
  final Set<String> _selected = {};

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _selected.isEmpty) return;
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final bundleBooks = _selected.map((bookId) {
      final price = int.tryParse(_prices[bookId]?.text ?? '') ?? 0;
      return BundleBook(id: '', bundleId: '', bookId: bookId, priceWon: price);
    }).toList();

    final bundle = SaleBundle(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: uid,
      title: _title.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      createdAt: DateTime.now(),
      books: bundleBooks,
    );
    await ref.read(bundleRepoProvider).createBundle(bundle);
    ref.invalidate(myBundlesProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(myBooksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('꾸러미 만들기'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '꾸러미 이름'),
          ),
          TextField(
            controller: _desc,
            decoration: const InputDecoration(labelText: '설명'),
          ),
          const Divider(),
          const Text('포함할 책 선택 (개별 가격 입력)'),
          books.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (list) => Column(
              children: list.map((b) {
                _prices.putIfAbsent(b.id, () => TextEditingController());
                return CheckboxListTile(
                  title: Text(b.title),
                  subtitle: _selected.contains(b.id)
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: TextField(
                            controller: _prices[b.id],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '가격(원)',
                              isDense: true,
                            ),
                          ),
                        )
                      : Text(b.author),
                  value: _selected.contains(b.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(b.id);
                    } else {
                      _selected.remove(b.id);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
