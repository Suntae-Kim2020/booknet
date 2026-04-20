import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreedTerms = false;
  bool _agreedPrivacy = false;
  bool _agreedMarketing = false;

  bool get _canProceed => _agreedTerms && _agreedPrivacy;

  void _toggleAll(bool? value) {
    final v = value ?? false;
    setState(() {
      _agreedTerms = v;
      _agreedPrivacy = v;
      _agreedMarketing = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allChecked = _agreedTerms && _agreedPrivacy && _agreedMarketing;

    return Scaffold(
      appBar: AppBar(title: const Text('약관 동의')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('환영합니다!',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('서비스 이용을 위해 아래 약관에 동의해주세요.',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),

              // 전체 동의
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  title: const Text('전체 동의',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  value: allChecked,
                  onChanged: _toggleAll,
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Divider(height: 32),

              // 이용약관 (필수)
              CheckboxListTile(
                title: const Text('[필수] 서비스 이용약관 동의'),
                subtitle: const Text('서비스 이용에 관한 기본 약관입니다.'),
                value: _agreedTerms,
                onChanged: (v) => setState(() => _agreedTerms = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: TextButton(
                  onPressed: () => _showTermsDetail(context, '서비스 이용약관',
                      '제1조 (목적)\n이 약관은 Booknet(이하 "서비스")의 이용에 관한 기본적인 사항을 규정함을 목적으로 합니다.\n\n제2조 (정의)\n1. "서비스"란 Booknet이 제공하는 도서 관리, 중고 거래, 독서토론 등의 기능을 말합니다.\n2. "회원"이란 서비스에 가입하여 이용하는 자를 말합니다.\n\n제3조 (서비스 이용)\n회원은 서비스를 통해 도서 등록, 꾸러미 판매, 독서토론 참여 등의 기능을 이용할 수 있습니다.'),
                  child: const Text('보기'),
                ),
              ),

              // 개인정보 수집 (필수)
              CheckboxListTile(
                title: const Text('[필수] 개인정보 수집·이용 동의'),
                subtitle: const Text('이름, 전화번호, 거래 정보를 수집합니다.'),
                value: _agreedPrivacy,
                onChanged: (v) => setState(() => _agreedPrivacy = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: TextButton(
                  onPressed: () => _showTermsDetail(context, '개인정보 수집·이용 동의',
                      '1. 수집 항목\n- 필수: 이름(닉네임), 전화번호, 이메일\n- 선택: 지역, 성별, 출생년도\n\n2. 수집 목적\n- 서비스 이용자 식별 및 회원 관리\n- 중고 도서 거래 시 연락 및 배송\n- 독서토론 매칭\n\n3. 보유 기간\n- 회원 탈퇴 시까지 (법령에 따른 보관 의무가 있는 경우 해당 기간)'),
                  child: const Text('보기'),
                ),
              ),

              // 마케팅 수신 (선택)
              CheckboxListTile(
                title: const Text('[선택] 마케팅 정보 수신 동의'),
                subtitle: const Text('카카오톡/문자로 이벤트, 할인 정보를 받습니다.'),
                value: _agreedMarketing,
                onChanged: (v) =>
                    setState(() => _agreedMarketing = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const Spacer(),

              // 다음 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _canProceed
                      ? () => context.go('/profile/setup', extra: {
                            'agreedTerms': _agreedTerms,
                            'agreedPrivacy': _agreedPrivacy,
                            'agreedMarketing': _agreedMarketing,
                          })
                      : null,
                  child: const Text('다음', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsDetail(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                child: Text(content, style: const TextStyle(height: 1.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
