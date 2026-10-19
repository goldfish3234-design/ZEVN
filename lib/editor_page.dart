import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'timeline.dart';

class EditorPage extends StatefulWidget {
  final String videoPath;
  const EditorPage({super.key, required this.videoPath});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late VideoPlayerController _controller;
  double _totalSec = 1;
  List<Segment> _segments = [];
  int _sel = 0;
  String _ratio = '16:9';
  String? _music;
  double _musicVol = 0.5;
  bool _exporting = false;
  bool _previewing = false;
  String? _error;

  // 1080p output size for each aspect ratio
  static const _sizes = {
    '16:9': [1920, 1080],
    '9:16': [1080, 1920],
    '1:1': [1080, 1080],
  };

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath));
    _controller.addListener(_onTick);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _totalSec = _controller.value.duration.inMilliseconds / 1000;
        if (_totalSec <= 0) _totalSec = 1;
        _segments = [Segment(0, _totalSec)];
        _sel = 0;
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load video:\n$e');
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  // Stops playback when the selected segment has been played to its end
  void _onTick() {
    if (!_previewing || _segments.isEmpty) return;
    final pos = _controller.value.position.inMilliseconds / 1000;
    if (pos >= _segments[_sel].end) {
      _controller.pause();
      _previewing = false;
      if (mounted) setState(() {});
    }
  }

  void _stopPreview() {
    if (_previewing) {
      _controller.pause();
      _previewing = false;
    }
  }

  void _togglePreview() {
    if (_previewing) {
      setState(_stopPreview);
      return;
    }
    final s = _segments[_sel];
    _controller.seekTo(Duration(milliseconds: (s.start * 1000).round()));
    _controller.play();
    setState(() => _previewing = true);
  }

  void _select(int i) {
    _stopPreview();
    setState(() => _sel = i);
  }

  void _changeSegment(int i, double start, double end) {
    _stopPreview();
    setState(() {
      _segments[i].start = start;
      _segments[i].end = end;
    });
  }

  void _cut() {
    if (_segments.length <= 1) return;
    _stopPreview();
    setState(() {
      _segments.removeAt(_sel);
      if (_sel >= _segments.length) _sel = _segments.length - 1;
    });
  }

  void _copy() {
    _stopPreview();
    setState(() {
      _segments.insert(_sel + 1, _segments[_sel].copy());
      _sel = _sel + 1;
    });
  }

  Future<void> _pickMusic() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = res?.files.single.path;
    if (path != null) setState(() => _music = path);
  }

  Future<void> _export() async {
    _stopPreview();
    setState(() => _exporting = true);
    final dir = await getTemporaryDirectory();
    final out =
        '${dir.path}/zevn_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final w = _sizes[_ratio]![0];
    final h = _sizes[_ratio]![1];
    final n = _segments.length;
    final hasMusic = _music != null;

    final f = StringBuffer();
    // Trim each segment from the video (video + audio)
    for (var i = 0; i < n; i++) {
      final s = _segments[i];
      f.write('[0:v]trim=start=${s.start}:end=${s.end},'
          'setpts=PTS-STARTPTS[v$i];');
      f.write('[0:a]atrim=start=${s.start}:end=${s.end},'
          'asetpts=PTS-STARTPTS[a$i];');
    }
    // Join the segments in order
    for (var i = 0; i < n; i++) {
      f.write('[v$i][a$i]');
    }
    f.write('concat=n=$n:v=1:a=1[cv][ca];');
    // Fit to the chosen aspect ratio at 1080p
    f.write('[cv]scale=$w:$h:force_original_aspect_ratio=decrease,'
        'pad=$w:$h:(ow-iw)/2:(oh-ih)/2[vout];');
    // Mix in music if picked, otherwise keep the original audio
    if (hasMusic) {
      f.write('[1:a]volume=$_musicVol[m];'
          '[ca][m]amix=inputs=2:duration=first:dropout_transition=0[aout]');
    } else {
      f.write('[ca]anull[aout]');
    }

    final inputs = hasMusic
        ? '-i "${widget.videoPath}" -i "$_music"'
        : '-i "${widget.videoPath}"';
    final cmd = '-y $inputs -filter_complex "${f.toString()}" '
        '-map "[vout]" -map "[aout]" '
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

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ZEVN Editor')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(fontSize: 16)),
        ),
      );
    }

    final ready = _controller.value.isInitialized && _segments.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('ZEVN Editor')),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              // Video preview, limited to about a third of the screen height
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.36,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                IconButton.filled(
                  onPressed: _togglePreview,
                  icon: Icon(_previewing ? Icons.pause : Icons.play_arrow),
                  tooltip: 'Play selected segment',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _controller,
                    builder: (context, v, _) => Text(
                      '${fmtSec(v.position.inMilliseconds / 1000)} / ${fmtSec(_totalSec)}',
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _Timeline(
                controller: _controller,
                segments: _segments,
                sel: _sel,
                total: _totalSec,
                onSelect: _select,
                onChange: _changeSegment,
              ),
              const SizedBox(height: 6),
              Text(
                'Selected: ${fmtSec(_segments[_sel].start)} - ${fmtSec(_segments[_sel].end)}'
                '   (drag the white edges to trim)',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(children: [
                OutlinedButton.icon(
                  onPressed: _segments.length > 1 ? _cut : null,
                  icon: const Icon(Icons.content_cut),
                  label: const Text('Cut'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('Music'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickMusic,
                icon: const Icon(Icons.music_note),
                label: Text(_music == null
                    ? 'Add music'
                    : _music!.split(RegExp(r'[/\\]')).last),
              ),
              if (_music != null) ...[
                Text('Music volume: ${(_musicVol * 100).round()}%'),
                Slider(
                  min: 0,
                  max: 1,
                  value: _musicVol,
                  onChanged: (v) => setState(() => _musicVol = v),
                ),
                TextButton(
                  onPressed: () => setState(() => _music = null),
                  child: const Text('Remove music'),
                ),
              ],
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

// Timeline: each segment is a block sized by its duration.
// The selected block has draggable edges, and a red line shows the playhead.
class _Timeline extends StatelessWidget {
  final VideoPlayerController controller;
  final List<Segment> segments;
  final int sel;
  final double total;
  final ValueChanged<int> onSelect;
  final void Function(int i, double start, double end) onChange;

  const _Timeline({
    required this.controller,
    required this.segments,
    required this.sel,
    required this.total,
    required this.onSelect,
    required this.onChange,
  });

  static const _height = 72.0;
  static const _handleW = 22.0;
  static const _minLen = 0.3; // seconds

  double _clamp(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final pos = value.position.inMilliseconds / 1000;
        return LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final playX = _clamp(pos / total * w, 0, w - 2);
          return SizedBox(
            height: _height,
            width: w,
            child: Stack(children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              for (var i = 0; i < segments.length; i++) _block(i, w),
              Positioned(
                left: playX,
                top: 0,
                bottom: 0,
                width: 2,
                child: Container(color: Colors.redAccent),
              ),
            ]),
          );
        });
      },
    );
  }

  Widget _block(int i, double w) {
    final s = segments[i];
    final isSel = i == sel;
    final left = s.start / total * w;
    final width = _clamp((s.end - s.start) / total * w, 4, w);

    return Positioned(
      left: left,
      top: 6,
      bottom: 6,
      width: width,
      child: GestureDetector(
        onTap: () => onSelect(i),
        child: Container(
          decoration: BoxDecoration(
            color: isSel ? Colors.deepPurple : Colors.blueGrey,
            borderRadius: BorderRadius.circular(6),
            border: isSel ? Border.all(color: Colors.white, width: 1.5) : null,
          ),
          child: Stack(children: [
            Center(
              child: Text('${i + 1}',
                  maxLines: 1, overflow: TextOverflow.clip),
            ),
            if (isSel) ...[
              // Left edge: moves the segment start
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _handleW,
                child: _handle((dx) {
                  final ds = dx / w * total;
                  final ns = _clamp(s.start + ds, 0, s.end - _minLen);
                  onChange(i, ns, s.end);
                }),
              ),
              // Right edge: moves the segment end
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _handleW,
                child: _handle((dx) {
                  final ds = dx / w * total;
                  final ne = _clamp(s.end + ds, s.start + _minLen, total);
                  onChange(i, s.start, ne);
                }),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _handle(void Function(double dx) onDrag) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      child: Center(
        child: Container(
          width: 5,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
