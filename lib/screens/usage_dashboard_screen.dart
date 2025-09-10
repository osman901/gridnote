// lib/screens/usage_dashboard_screen.dart
import 'package:flutter/material.dart';
import '../services/usage_analytics.dart';
import '../theme/gridnote_theme.dart';

class UsageDashboardScreen extends StatefulWidget {
  const UsageDashboardScreen({super.key, this.title = 'Uso (beta)'});
  final String title;

  @override
  State<UsageDashboardScreen> createState() => _UsageDashboardScreenState();
}

class _UsageDashboardScreenState extends State<UsageDashboardScreen> {
  Map<String, int> _data = const {};
  bool _loading = true;

  GridnoteTheme get t => GridnoteThemeController().theme;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await UsageAnalytics.instance.dump();
    setState(() {
      _data = m;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _data.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
          ? const Center(child: Text('Sin datos aún'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _data.length,
        separatorBuilder: (_, __) => Divider(color: t.divider),
        itemBuilder: (_, i) {
          final key = _data.keys.elementAt(i);
          final count = _data[key] ?? 0;
          final pct = total == 0 ? 0 : (count * 100 / total);
          return ListTile(
            title: Text(key),
            subtitle: Text('${pct.toStringAsFixed(1)}% • $count eventos'),
          );
        },
      ),
    );
  }
}
