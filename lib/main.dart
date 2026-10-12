import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'editor_page.dart';

void main() => runApp(const ZevnApp());

class ZevnApp extends StatelessWidget {
  const ZevnApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ZEVN',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Native Android channel implemented in MainActivity.kt
  static const _picker = MethodChannel('zevn/picker');

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _newProject(BuildContext context) async {
    try {
      final String? path = await _picker.invokeMethod<String>('pickVideo');
      if (!context.mounted) return;
      if (path == null) {
        _message(context, 'No video selected');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditorPage(videoPath: path)),
      );
    } catch (e) {
      if (!context.mounted) return;
      _message(context, 'Could not open gallery: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298), Color(0xFF000000)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const SizedBox(height: 24),
                const Text(
                  'ZEVN',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
                const Text('Simple Video Editor',
                    style: TextStyle(fontSize: 16, color: Colors.white70)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _newProject(context),
                    icon: const Icon(Icons.add),
                    label: const Text('New Project'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _message(context, 'Coming soon'),
                    icon: const Icon(Icons.folder),
                    label: const Text('My Projects'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
