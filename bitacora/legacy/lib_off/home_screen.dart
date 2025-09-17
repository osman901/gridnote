// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../repositories/sheets_repo.dart';
import 'sheets_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repo});
  final SheetsRepo repo;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      SheetsListScreen(repo: widget.repo),
      const _SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Planillas',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  Future<({String version, String build, String dir})> _info() async {
    final pkg = await PackageInfo.fromPlatform();
    final dir = await getApplicationDocumentsDirectory();
    return (version: pkg.version, build: pkg.buildNumber, dir: dir.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _info(),
      builder: (context, snap) {
        final theme = Theme.of(context);
        if (!snap.hasData) {
          return const Scaffold(
            appBar: _SimpleAppBar(title: 'Ajustes'),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final info = (snap.data as ({String version, String build, String dir}));
        return Scaffold(
          appBar: const _SimpleAppBar(title: 'Ajustes'),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Bitácora', style: theme.textTheme.titleLarge),
                subtitle: Text('Versión ${info.version} (build ${info.build})'),
                leading: const CircleAvatar(child: Icon(Icons.notes)),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: const Text('Carpeta de datos (local)'),
                subtitle: Text(info.dir),
              ),
              const Divider(height: 24),
              const Text('Privacidad', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Todos los datos (planillas, fotos y exportaciones) se guardan solo en '
                    'el almacenamiento privado de la app. No se sube nada a servidores.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pronto: respaldo/restore local.')),
                  );
                },
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Respaldo local (próximamente)'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SimpleAppBar({required this.title});
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title), centerTitle: false);
  }
}
