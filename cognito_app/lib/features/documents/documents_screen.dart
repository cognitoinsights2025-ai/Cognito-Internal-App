import 'package:flutter/material.dart';
import '../../core/theme.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  static final _docs = [
    _Doc('Employee Handbook 2026', 'HR', Icons.menu_book_rounded, '2.1 MB', 'PDF', AppColors.rose),
    _Doc('Attendance Policy', 'HR', Icons.policy_rounded, '340 KB', 'PDF', AppColors.warning),
    _Doc('Code of Conduct', 'HR', Icons.gavel_rounded, '520 KB', 'PDF', AppColors.purple),
    _Doc('Payroll Structure', 'Finance', Icons.payments_rounded, '1.2 MB', 'XLSX', AppColors.success),
    _Doc('Tax Declarations 2025-26', 'Finance', Icons.receipt_long_rounded, '890 KB', 'PDF', AppColors.success),
    _Doc('Dev Environment Setup Guide', 'Technical', Icons.code_rounded, '1.5 MB', 'PDF', AppColors.info),
    _Doc('Project Architecture Overview', 'Technical', Icons.architecture_rounded, '3.2 MB', 'PDF', AppColors.info),
    _Doc('API Documentation', 'Technical', Icons.api_rounded, '4.1 MB', 'PDF', AppColors.cyan),
    _Doc('Cognito Brand Guidelines', 'General', Icons.palette_rounded, '6.5 MB', 'PDF', AppColors.amber),
    _Doc('Office Contact Directory', 'General', Icons.contacts_rounded, '180 KB', 'PDF', AppColors.primary),
    _Doc('Cognito Employee Details', 'HR', Icons.people_rounded, '65 KB', 'PDF', AppColors.primaryMid),
  ];

  static const _folders = ['All', 'HR', 'Finance', 'Technical', 'General'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _folders.length,
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: const Text('Documents'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabs: _folders.map((f) => Tab(text: f)).toList(),
          ),
        ),
        body: TabBarView(
          children: _folders.map((folder) {
            final filtered = folder == 'All' ? _docs : _docs.where((d) => d.folder == folder).toList();
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) => _docCard(filtered[i]),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _docCard(_Doc doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: CardDecor.standard(),
      child: Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(color: doc.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(doc.icon, color: doc.color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: doc.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(doc.type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: doc.color))),
            const SizedBox(width: 6),
            Text(doc.size, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ])),
        IconButton(
          icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 22),
          onPressed: () {},
        ),
      ]),
    );
  }
}

class _Doc {
  final String name, folder, size, type;
  final IconData icon;
  final Color color;
  _Doc(this.name, this.folder, this.icon, this.size, this.type, this.color);
}
