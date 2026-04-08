import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _price = TextEditingController();
  final Set<String> _selected = {};

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _selected.isEmpty) return;
    final repo = ref.read(supabaseRepoProvider);
    final bundle = SaleBundle(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: 'me', // TODO: Supabase auth user id
      title: _title.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      priceWon: int.tryParse(_price.text) ?? 0,
      bookIds: _selected.toList(),
      createdAt: DateTime.now(),
    );
    await repo.createBundle(bundle);
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
          TextField(
            controller: _price,
            decoration: const InputDecoration(labelText: '가격(원)'),
            keyboardType: TextInputType.number,
          ),
          const Divider(),
          const Text('포함할 책 선택'),
          books.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (list) => Column(
              children: list
                  .map((b) => CheckboxListTile(
                        title: Text(b.title),
                        subtitle: Text(b.author),
                        value: _selected.contains(b.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(b.id);
                          } else {
                            _selected.remove(b.id);
                          }
                        }),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
