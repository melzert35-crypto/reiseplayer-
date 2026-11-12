import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReisePlayerApp());
}

enum MediaKind { audio, video }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.name,
    required this.path,
    required this.kind,
    required this.bytes,
  });

  final String id;
  final String name;
  final String path;
  final MediaKind kind;
  final int bytes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'kind': kind.name,
        'bytes': bytes,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        kind: json['kind'] == 'video' ? MediaKind.video : MediaKind.audio,
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      );
}

class ReisePlayerApp extends StatelessWidget {
  const ReisePlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF65D6B0);
    return MaterialApp(
      title: 'ReisePlayer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF10151B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF10151B),
          centerTitle: false,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _storageKey = 'reiseplayer_library_v1';
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<MediaItem> _items = [];
  int _tab = 0;
  String? _currentAudioId;
  bool _loading = true;
  bool _importing = false;
  String? _message;

  List<MediaItem> get _audioItems =>
      _items.where((item) => item.kind == MediaKind.audio).toList();

  List<MediaItem> get _videoItems =>
      _items.where((item) => item.kind == MediaKind.video).toList();

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final entry in decoded) {
          final item = MediaItem.fromJson(
            Map<String, dynamic>.from(entry as Map),
          );
          if (await File(item.path).exists()) {
            _items.add(item);
          }
        }
      }
    } catch (_) {
      _message = 'Die gespeicherte Medienliste konnte nicht vollständig gelesen werden.';
    }
    if (mounted) {
      setState(() => _loading = false);
      await _saveLibrary();
    }
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _importFiles(MediaKind kind) async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _message = null;
    });

    try {
      final extensions = kind == MediaKind.audio
          ? ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus']
          : ['mp4', 'm4v', 'mov', 'mkv', 'webm', '3gp'];
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: true,
        withReadStream: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${appDir.path}/reiseplayer_media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      int added = 0;
      for (final picked in result.files) {
        final originalName = picked.name;
        final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final uniqueName = '${DateTime.now().microsecondsSinceEpoch}_$safeName';
        final destination = File('${mediaDir.path}/$uniqueName');

        if (picked.path != null) {
          await File(picked.path!).copy(destination.path);
        } else if (picked.readStream != null) {
          final sink = destination.openWrite();
          await sink.addStream(picked.readStream!);
          await sink.close();
        } else if (picked.bytes != null) {
          await destination.writeAsBytes(picked.bytes!, flush: true);
        } else {
          continue;
        }

        final size = await destination.length();
        _items.add(
          MediaItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: originalName,
            path: destination.path,
            kind: kind,
            bytes: size,
          ),
        );
        added++;
      }

      await _saveLibrary();
      if (mounted) {
        setState(() {
          _message = added == 0
              ? 'Keine Datei konnte importiert werden.'
              : '$added Datei(en) wurden in die Mediathek übernommen.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Import fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _playAudio(MediaItem item) async {
    try {
      await _audioPlayer.setFilePath(item.path);
      await _audioPlayer.play();
      if (mounted) setState(() => _currentAudioId = item.id);
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Diese Audiodatei kann nicht abgespielt werden: $error');
      }
    }
  }

  Future<void> _deleteItem(MediaItem item) async {
    if (item.id == _currentAudioId) {
      await _audioPlayer.stop();
      _currentAudioId = null;
    }
    try {
      final file = File(item.path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Der Eintrag wird auch dann aus der Liste entfernt, wenn die Datei fehlt.
    }
    _items.removeWhere((entry) => entry.id == item.id);
    await _saveLibrary();
    if (mounted) {
      setState(() => _message = 'Datei aus der Mediathek entfernt.');
    }
  }

  Future<void> _openYouTube() async {
    final uri = Uri.parse('https://m.youtube.com/');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _message = 'YouTube konnte nicht geöffnet werden.');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Musik', 'Videos', 'Meine Mediathek'];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.headphones, color: Color(0xFF65D6B0)),
            SizedBox(width: 10),
            Text('ReisePlayer'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'YouTube online öffnen',
            onPressed: _openYouTube,
            icon: const Icon(Icons.smart_display_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _introCard(),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_message!)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _message = null),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      _mediaList(_audioItems, MediaKind.audio),
                      _mediaList(_videoItems, MediaKind.video),
                      _libraryOverview(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.music_note), label: 'Musik'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'Videos'),
          NavigationDestination(icon: Icon(Icons.library_music), label: 'Mediathek'),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B3938), Color(0xFF1C2935)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deine Musik. Deine Videos. Offline bereit.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Importiere Dateien vom Handy. Danach brauchst du zum Abspielen kein Internet.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _importing ? null : () => _importFiles(MediaKind.audio),
                  icon: const Icon(Icons.add),
                  label: const Text('Musik hinzufügen'),
                ),
                OutlinedButton.icon(
                  onPressed: _importing ? null : () => _importFiles(MediaKind.video),
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Videos hinzufügen'),
                ),
              ],
            ),
            if (_importing) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              const Text('Dateien werden übernommen…', style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mediaList(List<MediaItem> items, MediaKind kind) {
    if (items.isEmpty) {
      return _emptyState(
        kind == MediaKind.audio ? Icons.music_off : Icons.video_library_outlined,
        kind == MediaKind.audio
            ? 'Noch keine Musik vorhanden'
            : 'Noch keine Videos vorhanden',
        'Tippe oben auf „${kind == MediaKind.audio ? 'Musik' : 'Videos'} hinzufügen“ und wähle Dateien aus.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final isCurrent = item.id == _currentAudioId;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              kind == MediaKind.audio ? Icons.music_note : Icons.movie,
              color: const Color(0xFF65D6B0),
            ),
          ),
          title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(_formatBytes(item.bytes)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kind == MediaKind.audio)
                IconButton(
                  tooltip: isCurrent ? 'Wird gerade abgespielt' : 'Abspielen',
                  onPressed: () => _playAudio(item),
                  icon: Icon(
                    isCurrent ? Icons.graphic_eq : Icons.play_circle_outline,
                    color: const Color(0xFF65D6B0),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Video ansehen',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoPage(item: item),
                    ),
                  ),
                  icon: const Icon(Icons.play_circle_outline, color: Color(0xFF65D6B0)),
                ),
              IconButton(
                tooltip: 'Löschen',
                onPressed: () => _confirmDelete(item),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(MediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datei löschen?'),
        content: Text('„${item.name}“ wird aus der ReisePlayer-Mediathek gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteItem(item);
  }

  Widget _libraryOverview() {
    final totalBytes = _items.fold<int>(0, (sum, item) => sum + item.bytes);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statCard(Icons.music_note, 'Musikdateien', '${_audioItems.length}'),
        const SizedBox(height: 10),
        _statCard(Icons.movie, 'Videos', '${_videoItems.length}'),
        const SizedBox(height: 10),
        _statCard(Icons.storage, 'Gespeicherter Speicher', _formatBytes(totalBytes)),
        const SizedBox(height: 18),
        const Text(
          'Hinweis zu YouTube',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Der YouTube-Knopf öffnet YouTube separat. Videos werden nicht aus YouTube herausgeladen. '
          'Offizielle YouTube-Offline-Downloads bleiben in der YouTube-App. '
          'Eigene Dateien und ausdrücklich zum Download freigegebene Inhalte kannst du hier importieren.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _openYouTube,
          icon: const Icon(Icons.open_in_new),
          label: const Text('YouTube öffnen'),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF65D6B0)),
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Colors.white38),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 7),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}

class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.item});

  final MediaItem item;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.item.path));
    _controller.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((Object error) {
      if (mounted) setState(() => _error = 'Video kann nicht geöffnet werden: $error');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            : !_ready
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                      const SizedBox(height: 18),
                      VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      const SizedBox(height: 8),
                      IconButton.filled(
                        iconSize: 38,
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          });
                        },
                        icon: Icon(
                          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
