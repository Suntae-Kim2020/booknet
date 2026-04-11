import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book.dart';
import '../../providers.dart';

/// 표지 촬영 후 키워드로 도서 검색.
/// ML Kit OCR은 실기기 전용이므로, 현재는 사진 촬영 → 수동 검색 방식.
class BookPhotoScreen extends ConsumerStatefulWidget {
  const BookPhotoScreen({super.key});

  @override
  ConsumerState<BookPhotoScreen> createState() => _BookPhotoScreenState();
}

class _BookPhotoScreenState extends ConsumerState<BookPhotoScreen> {
  File? _imageFile;
  final _queryCtrl = TextEditingController();
  bool _loading = false;
  List<Book> _results = [];

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    final books = await ref.read(naverBookApiProvider).searchByKeyword(q);
    setState(() {
      _results = books;
      _loading = false;
    });
  }

  Future<void> _registerBook(Book book) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final bookWithOwner = Book(
      id: book.id,
      ownerId: uid,
      isbn: book.isbn,
      title: book.title,
      author: book.author,
      publisher: book.publisher,
      coverUrl: book.coverUrl,
      description: book.description,
      publishedAt: book.publishedAt,
    );
    await ref.read(bookRepoProvider).upsertBook(bookWithOwner);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('등록: ${book.title}')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('표지 촬영으로 등록')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_imageFile!, height: 250, fit: BoxFit.cover),
            )
          else
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('책 표지를 촬영하고\n제목을 입력해 검색하세요',
                    textAlign: TextAlign.center),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('촬영'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _queryCtrl,
            decoration: InputDecoration(
              hintText: '표지에서 본 제목/저자 입력',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
          if (_loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (_results.isNotEmpty) ...[
            const Divider(height: 24),
            ...ListTile.divideTiles(
              context: context,
              tiles: _results.map((b) => ListTile(
                    leading: b.coverUrl != null
                        ? Image.network(b.coverUrl!, width: 40)
                        : const Icon(Icons.book),
                    title: Text(b.title),
                    subtitle: Text('${b.author} · ${b.publisher}'),
                    trailing: FilledButton(
                      onPressed: () => _registerBook(b),
                      child: const Text('등록'),
                    ),
                  )),
            ),
          ],
        ],
      ),
    );
  }
}
