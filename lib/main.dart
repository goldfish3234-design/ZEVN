import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<void> _newProject(BuildContext context) async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorPage(videoPath: file.path)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/images/hero.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text(
                  'ZEVN',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
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
                    onPressed: () {},
                    icon: const Icon(Icons.folder),
                    label: const Text('My Projects'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      );
}
