import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class EditorPage extends StatefulWidget {
  final String videoPath;
  const EditorPage({super.key, required this.videoPath});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late VideoPlayerController _controller;
  double _totalSec = 1, _start = 0, _end = 1;
  String _ratio = '16:9';
  bool _exporting = false;

  // 1080p output size for each aspect ratio
  static const _sizes = {
    '16:9': [1920, 1080],
    '9:16': [1080, 1920],
    '1:1': [1080, 1080],
  };

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _totalSec = _controller.value.duration.inMilliseconds / 1000;
          _end = _totalSec;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final dir = await getTemporaryDirectory();
    final out =
        '${dir.path}/zevn_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final w = _sizes[_ratio]![0];
    final h = _sizes[_ratio]![1];

    final cmd = '-y -ss $_start -i "${widget.videoPath}" '
        '-t ${_end - _start} '
        '-vf "scale=$w:$h:force_original_aspect_ratio=decrease,'
        'pad=$w:$h:(ow-iw)/2:(oh-ih)/2" '
        '-c:v libx264 -preset veryfast -crf 23 -c:a aac "$out"';

    final session = await FFmpegKit.execute(cmd);
    final ok = ReturnCode.isSuccess(await session.getReturnCode());
    if (ok) await Gal.putVideo(out);

    if (!mounted) return;
    setState(() => _exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Saved to Gallery ($_ratio, 1080p)' : 'Export failed'),
    ));
  }

  String _fmt(double s) => '${s.toStringAsFixed(1)}s';

  @override
  Widget build(BuildContext context) {
    final ready = _controller.value.isInitialized;
    return Scaffold(
      appBar: AppBar(title: const Text('ZEVN Editor')),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              const SizedBox(height: 16),
              Text('Trim: ${_fmt(_start)} - ${_fmt(_end)}'),
              RangeSlider(
                min: 0,
                max: _totalSec,
                values: RangeValues(_start, _end),
                onChanged: (v) => setState(() {
                  _start = v.start;
                  _end = v.end;
                }),
              ),
              const SizedBox(height: 16),
              const Text('Aspect Ratio'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: _sizes.keys
                    .map((k) => ButtonSegment(value: k, label: Text(k)))
                    .toList(),
                selected: {_ratio},
                onSelectionChanged: (s) => setState(() => _ratio = s.first),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_alt),
                label: Text(_exporting ? 'Exporting...' : 'Export 1080p'),
              ),
            ]),
    );
  }
}
