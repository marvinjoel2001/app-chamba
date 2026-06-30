import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../../core/network/cloudinary_upload_service.dart';
import '../../../request/presentation/screens/request_modality_screen.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../../domain/usecases/messages_usecases.dart';
import '../state/messages_dependencies.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.threadId,
    this.jobId = '',
    this.jobTitle = 'Trabajo',
    this.jobStatus = ChatThreadStatus.active,
    this.agreedPrice = 0,
    this.counterpartName = '',
    this.counterpartAvatarUrl,
    this.category,
    this.workerId,
    this.isArchived = false,
    this.getThreadMessagesUseCase,
    this.sendMessageUseCase,
    super.key,
  });

  final String threadId;
  final String jobId;
  final String jobTitle;
  final ChatThreadStatus jobStatus;
  final double agreedPrice;
  final String counterpartName;
  final String? counterpartAvatarUrl;
  final String? category;
  final String? workerId;
  final bool isArchived;
  final GetThreadMessagesUseCase? getThreadMessagesUseCase;
  final SendMessageUseCase? sendMessageUseCase;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  GetThreadMessagesUseCase get _getThreadMessagesUseCase =>
      widget.getThreadMessagesUseCase ?? MessagesDependencies.getThreadMessages;
  SendMessageUseCase get _sendMessageUseCase =>
      widget.sendMessageUseCase ?? MessagesDependencies.sendMessage;

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(value.year, value.month, value.day);
    final diff = today.difference(messageDay).inDays;
    final timeStr =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return timeStr;
    if (diff == 1) return 'Ayer $timeStr';
    return '${value.day}/${value.month}/${value.year} $timeStr';
  }

  final controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final RealtimeService _realtime = RealtimeService.instance;
  final Set<String> _readMessageIds = {};
  bool _loading = true;
  bool _isOffline = false;
  bool _shouldRedirectToLogin = false;
  bool _isNearBottom = true;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  String? _error;
  List<ChatMessage> _messages = const [];

  // Audio recording & playback
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _playerCompleteSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  String? _recordingPath;
  String? _currentlyPlayingAudioUrl;
  bool _isPlayingAudio = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  // Image preview before sending
  File? _pendingImage;
  bool _isSendingMedia = false;
  bool _isSending = false;
  final Set<String> _pendingMessageIds = {};

  @override
  void initState() {
    super.initState();
    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.joinThread(widget.threadId);
    _realtime.on('message.new', _onMessageNew);
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_markVisibleMessagesAsRead);
    _initAudioListeners();
    _load();
  }

  void _initAudioListeners() {
    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _audioPosition = Duration.zero;
        });
      }
    });
    _positionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _audioPosition = position);
      }
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _audioDuration = duration);
      }
    });
  }

  @override
  void dispose() {
    _realtime.off('message.new', _onMessageNew);
    _playerCompleteSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isDuplicateMessage(String messageId, String? content, String senderId, DateTime? createdAt) {
    if (messageId.isNotEmpty && _messages.any((m) => m.id == messageId)) return true;
    final now = DateTime.now();
    final time = createdAt ?? now;
    return _messages.any((m) => 
      m.content == content && 
      m.senderUserId == senderId && 
      (m.createdAt ?? now).difference(time).inSeconds.abs() < 5
    );
  }

  void _onMessageNew(dynamic payload) {
    if (!mounted) return;
    Map<String, dynamic> map = {};
    if (payload is Map) {
      map = Map<String, dynamic>.from(payload);
    } else if (payload is String) {
      try {
        map = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      } catch (_) {}
    }
    
    final threadId = map['threadId']?.toString();
    if (threadId != widget.threadId) {
      return;
    }

    final messageId = map['message']?['id']?.toString();
    final senderId = map['message']?['senderUserId']?.toString();
    final content = map['message']?['content']?.toString();

    if (messageId != null && senderId != null) {
      // Prevent duplicates - check if message already exists
      if (_isDuplicateMessage(messageId, content, senderId, DateTime.now())) {
        return;
      }

      // Also check if we just sent this message locally
      if (_pendingMessageIds.contains(messageId)) {
        _pendingMessageIds.remove(messageId);
        return;
      }

      final newMessage = ChatMessage(
        id: messageId,
        threadId: threadId ?? widget.threadId,
        senderUserId: senderId,
        content: content,
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages = [..._messages, newMessage];
      });

      if (_isNearBottom) {
        _scrollToBottom();
      }
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
    if (_showEmojiPicker) {
      _focusNode.unfocus();
    }
  }

  void _onEmojiSelected(emoji) {
    controller.text = controller.text + (emoji?.emoji ?? '');
  }

  Widget _buildMessageInput() {
    final bool hasText = controller.text.isNotEmpty;
    final bool hasPendingImage = _pendingImage != null;
    final bool hasPendingAudio = !_isRecording && _recordingPath != null;

    if (hasPendingImage) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.colorSurfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _pendingImage!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _cancelPendingImage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Agregar leyenda...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                if (_isSendingMedia)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.colorPrimary,
                    child: IconButton(
                      onPressed: () => _sendImageMessage(_pendingImage!),
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.colorSurfaceSoft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: AppTheme.colorError),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Grabando audio...',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.colorError),
              ),
            ),
            IconButton(
              onPressed: _cancelRecording,
              icon: const Icon(Icons.delete_outline, color: AppTheme.colorMuted),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.colorError,
              child: IconButton(
                onPressed: () => _stopRecording(send: false),
                icon: const Icon(Icons.stop, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );
    }

    if (hasPendingAudio) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.colorSurfaceSoft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.audio_file, color: AppTheme.colorPrimary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Audio listo',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              onPressed: _cancelRecording,
              icon: const Icon(Icons.delete_outline, color: AppTheme.colorMuted),
            ),
            if (_isSendingMedia)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.colorPrimary,
                child: IconButton(
                  onPressed: () {
                    _sendVoiceMessage(_recordingPath!);
                    setState(() => _recordingPath = null);
                  },
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: _toggleEmojiPicker,
            icon: Icon(
              _showEmojiPicker ? Icons.keyboard : Icons.add_circle_outline,
              color: AppTheme.colorPrimary,
            ),
          ),
          IconButton(
            onPressed: _showAttachmentMenu,
            icon: const Icon(
              Icons.image_outlined,
              color: AppTheme.colorPrimary,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.multiline,
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              enabled: !_isSendingMedia,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
          ),
          if (hasText)
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.colorPrimary,
              child: IconButton(
                onPressed: _isSendingMedia ? null : _send,
                icon: _isSendingMedia
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            )
          else
            GestureDetector(
              onTap: _startRecording,
              child: const CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.colorPrimary,
                child: Icon(Icons.mic_none, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  void _cancelPendingImage() {
    setState(() => _pendingImage = null);
    controller.clear();
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.colorSurfaceSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Adjuntar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.image,
                  label: 'Galeria',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camara',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(camera: true);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Documento',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      // Check microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return;
      }

      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording({bool send = false}) async {
    try {
      if (!await _audioRecorder.isRecording()) return;

      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);

      if (send && path != null) {
        await _sendVoiceMessage(path);
        setState(() => _recordingPath = null);
      } else if (path != null) {
        setState(() => _recordingPath = path);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
      });
    }
  }

  Future<void> _sendVoiceMessage(String path) async {
    if (_isSendingMedia) return; // Prevent double send
    setState(() => _isSendingMedia = true);
    try {
      final file = File(path);
      if (!await file.exists()) return;

      // Upload audio file to Cloudinary and get URL
      final bytes = await file.readAsBytes();
      final uploadResult = await CloudinaryUploadService.uploadFileBytes(
        bytes: bytes,
        fileName: path.split('/').last,
        folder: 'chat_audio',
        resourceType: 'video', // Audio uses video endpoint in Cloudinary
      );
      final audioUrl = uploadResult.secureUrl;

      final currentUserId = SessionStore.currentUser?.id ?? '';
      final result = await _sendMessageUseCase.call(
        threadId: widget.threadId,
        senderUserId: currentUserId,
        content: '🎤 Mensaje de voz [${await _getAudioDuration(path)}s]\n$audioUrl',
      );

      if (!mounted) return;
      result.fold(
        onSuccess: (sentMessage) {
          _pendingMessageIds.add(sentMessage.id);
          if (!_isDuplicateMessage(sentMessage.id, sentMessage.content, sentMessage.senderUserId, sentMessage.createdAt)) {
            setState(() {
              _messages = [..._messages, sentMessage];
            });
          }
          _scrollToBottom();
        },
        onFailure: (failure) {
          setState(() => _error = 'Error enviando audio: ${failure.message}');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Error enviando audio: $e');
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
    }
  }

  Future<int> _getAudioDuration(String path) async {
    // Simple duration estimation based on file size
    try {
      final file = File(path);
      final size = await file.length();
      // Rough estimate: ~16KB per second at 128kbps
      return (size / 16000).ceil();
    } catch (e) {
      return 0;
    }
  }

  // Helper methods to detect message type from content
  bool _isAudioMessage(String? content) {
    if (content == null) return false;
    return content.contains('🎤') ||
        content.contains('.m4a') ||
        content.contains('.mp3') ||
        content.contains('.aac') ||
        content.contains('.webm') ||
        content.contains('.wav') ||
        content.contains('audio');
  }

  bool _isImageMessage(String? content) {
    if (content == null) return false;
    return content.contains('📷') ||
        content.contains('.jpg') ||
        content.contains('.jpeg') ||
        content.contains('.png') ||
        content.contains('.webp') ||
        content.contains('image');
  }

  String? _extractUrl(String content) {
    // Extract URL from content using regex
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)|(file:\/\/[^\s]+)');
    final match = urlRegex.firstMatch(content);
    return match?.group(0);
  }

  Future<void> _playAudio(String url) async {
    try {
      if (_currentlyPlayingAudioUrl == url && _isPlayingAudio) {
        // Pause current
        await _audioPlayer.pause();
        setState(() {
          _isPlayingAudio = false;
        });
      } else if (_currentlyPlayingAudioUrl == url && !_isPlayingAudio) {
        // Resume
        await _audioPlayer.resume();
        setState(() {
          _isPlayingAudio = true;
        });
      } else {
        // Play new
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
        if (!mounted) return;
        setState(() {
          _currentlyPlayingAudioUrl = url;
          _isPlayingAudio = true;
          _audioPosition = Duration.zero;
          _audioDuration = Duration.zero;
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error reproduciendo audio')),
      );
    }
  }

  void _showFullScreenImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 64,
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      await _sendFileMessage(file.path!, file.name, file.size);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error seleccionando archivo: $e');
    }
  }

  Future<void> _sendFileMessage(String path, String name, int size) async {
    setState(() => _isSendingMedia = true);
    try {
      // Upload file to Cloudinary and get URL
      final fileObj = File(path);
      final bytes = await fileObj.readAsBytes();
      final uploadResult = await CloudinaryUploadService.uploadFileBytes(
        bytes: bytes,
        fileName: name,
        folder: 'chat_files',
        resourceType: 'auto',
      );
      final fileUrl = uploadResult.secureUrl;

      final currentUserId = SessionStore.currentUser?.id ?? '';
      final result = await _sendMessageUseCase.call(
        threadId: widget.threadId,
        senderUserId: currentUserId,
        content: '📎 $name\n$fileUrl',
      );

      if (!mounted) return;
      result.fold(
        onSuccess: (sentMessage) {
          _pendingMessageIds.add(sentMessage.id);
          if (!_isDuplicateMessage(sentMessage.id, sentMessage.content, sentMessage.senderUserId, sentMessage.createdAt)) {
            setState(() {
              _messages = [..._messages, sentMessage];
            });
          }
          _scrollToBottom();
        },
        onFailure: (failure) {
          setState(() => _error = 'Error enviando archivo: ${failure.message}');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Error enviando archivo: $e');
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
    }
  }

  Future<void> _pickImage({bool camera = false}) async {
    try {
      final picker = ImagePicker();
      final source = camera ? ImageSource.camera : ImageSource.gallery;

      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (picked == null || !mounted) return;

      // Show preview before sending
      setState(() => _pendingImage = File(picked.path));
    } catch (e) {
      if (mounted) setState(() => _error = 'Error seleccionando imagen: $e');
    }
  }

  Future<void> _sendImageMessage(File imageFile) async {
    if (_isSendingMedia) return; // Prevent double send
    setState(() => _isSendingMedia = true);
    try {
      // Upload image to Cloudinary and get URL
      final bytes = await imageFile.readAsBytes();
      final uploadResult = await CloudinaryUploadService.uploadFileBytes(
        bytes: bytes,
        fileName: imageFile.path.split('/').last,
        folder: 'chat_images',
        resourceType: 'image',
      );
      final imageUrl = uploadResult.secureUrl;

      final currentUserId = SessionStore.currentUser?.id ?? '';
      final result = await _sendMessageUseCase.call(
        threadId: widget.threadId,
        senderUserId: currentUserId,
        content: '📷 Imagen enviada\n$imageUrl',
      );

      if (!mounted) return;
      result.fold(
        onSuccess: (sentMessage) {
          _pendingMessageIds.add(sentMessage.id);
          if (!_messages.any((m) => m.id == sentMessage.id)) {
            setState(() {
              _pendingImage = null;
              _messages = [..._messages, sentMessage];
            });
          } else {
            setState(() => _pendingImage = null);
          }
          _scrollToBottom();
        },
        onFailure: (failure) {
          setState(() => _error = 'Error enviando imagen: ${failure.message}');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Error enviando imagen: $e');
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    _isNearBottom = (maxScroll - currentScroll) < 100;
  }

  void _markVisibleMessagesAsRead() {
    // Implement read tracking based on viewport visibility
    // For now, mark last few messages as read when near bottom
    if (_isNearBottom && _messages.isNotEmpty) {
      final currentUserId = SessionStore.currentUser?.id;
      final lastMessages = _messages.reversed.take(5);

      for (final msg in lastMessages) {
        if (msg.senderUserId != currentUserId &&
            !_readMessageIds.contains(msg.id)) {
          _readMessageIds.add(msg.id);
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _load() async {
    // Solo mostrar spinner cuando aun no hay mensajes cargados;
    // en refrescos posteriores se actualiza en silencio.
    final isFirstLoad = _messages.isEmpty;
    if (isFirstLoad) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final result = await _getThreadMessagesUseCase(threadId: widget.threadId);
    if (!mounted) return;

    result.fold(
      onSuccess: (messages) {
        setState(() {
          _messages = messages;
          _isOffline = false;
          _shouldRedirectToLogin = false;
          _error = null;
          _loading = false;
        });
        if (isFirstLoad) {
          _jumpToBottom();
        }
      },
      onFailure: (failure) {
        setState(() {
          if (isFirstLoad) _error = failure.message;
          _isOffline = failure is NetworkFailure;
          _shouldRedirectToLogin = failure is UnauthorizedFailure;
          _loading = false;
        });
      },
    );
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    if (_isSending) return; // Prevent double send

    final user = SessionStore.currentUser;
    final content = controller.text.trim();
    if (user == null || content.isEmpty || widget.isArchived) {
      return;
    }

    setState(() => _isSending = true);

    final result = await _sendMessageUseCase(
      threadId: widget.threadId,
      senderUserId: user.id,
      content: content,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (sentMessage) {
        controller.clear();
        _pendingMessageIds.add(sentMessage.id);
        if (!_isDuplicateMessage(sentMessage.id, sentMessage.content, sentMessage.senderUserId, sentMessage.createdAt)) {
          setState(() {
            _messages = [..._messages, sentMessage];
          });
        }
        _scrollToBottom();
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );

    setState(() => _isSending = false);
  }

  Color _statusColor(ChatThreadStatus status) {
    switch (status) {
      case ChatThreadStatus.active:
        return AppTheme.colorSuccess;
      case ChatThreadStatus.completed:
        return AppTheme.colorPrimary;
      case ChatThreadStatus.cancelled:
        return AppTheme.colorError;
    }
  }

  String _statusLabel(ChatThreadStatus status) {
    switch (status) {
      case ChatThreadStatus.active:
        return 'Activo';
      case ChatThreadStatus.completed:
        return 'Completado';
      case ChatThreadStatus.cancelled:
        return 'Cancelado';
    }
  }

  void _rehire() {
    if (widget.workerId == null || widget.category == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestModalityScreen(
          initialPrompt: 'Volver a contratar: ${widget.jobTitle}',
          preselectedCategory: widget.category,
          preselectedWorkerId: widget.workerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SessionStore.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F0FF), Colors.white],
            stops: [0.0, 0.2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Light Theme Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: AppTheme.colorPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category ?? widget.jobTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            widget.jobTitle,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {}, // Action for phone call
                      icon: const Icon(Icons.phone_outlined, color: AppTheme.colorPrimary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              if (_isOffline)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Sin conexion.',
                    style: TextStyle(color: AppTheme.colorMuted),
                  ),
                ),

              if (_shouldRedirectToLogin)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Sesion expirada.',
                    style: TextStyle(color: AppTheme.colorError),
                  ),
                ),

              // Job Summary Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.jobTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, size: 14, color: AppTheme.colorSuccess),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.agreedPrice} Bs. Acordado',
                          style: const TextStyle(color: AppTheme.colorSuccess, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.colorPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.category ?? 'Trabajo',
                            style: const TextStyle(
                              color: AppTheme.colorPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        ChambaNetworkAvatar(
                          url: widget.counterpartAvatarUrl,
                          radius: 12,
                          fallbackText: widget.counterpartName.trim().isEmpty ? '?' : widget.counterpartName.trim().substring(0, 1).toUpperCase(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Trabajador: ${widget.counterpartName}',
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final widgets = <Widget>[];

                              // Show date divider if date changed (WhatsApp style)
                              if (_shouldShowDateHeader(index)) {
                                widgets
                                    .add(_buildDateHeader(message.createdAt));
                              }

                              if (message.isSystem) {
                                widgets.add(_buildSystemMessage(message));
                              } else {
                                final mine =
                                    message.senderUserId == currentUserId;
                                widgets.add(_buildTextMessage(message, mine));
                              }

                              return Column(children: widgets);
                            },
                          ),
              ),

              // Rehire button for archived chats
              if (widget.isArchived &&
                  widget.workerId != null &&
                  widget.category != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ChambaPrimaryButton(
                    label: 'Volver a contratar',
                    onPressed: _rehire,
                  ),
                ),

              // Emoji picker
              if (_showEmojiPicker)
                SizedBox(
                  height: 250,
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) =>
                        _onEmojiSelected(emoji),
                    config: const Config(
                      height: 250,
                      checkPlatformCompatibility: true,
                      viewOrderConfig: ViewOrderConfig(),
                      skinToneConfig: SkinToneConfig(),
                      categoryViewConfig: CategoryViewConfig(),
                      bottomActionBarConfig:
                          BottomActionBarConfig(enabled: false),
                      searchViewConfig: SearchViewConfig(),
                      emojiViewConfig: EmojiViewConfig(
                        emojiSizeMax: 28,
                        columns: 8,
                      ),
                    ),
                  ),
                ),

              // Message input (disabled for archived chats) - WhatsApp style
              // ValueListenableBuilder evita reconstruir toda la pantalla en
              // cada tecla: solo se reconstruye el input.
              if (!widget.isArchived)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, _, __) => _buildMessageInput(),
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FA), // Very light purple/grey
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                message.displayContent,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mock badge as requested in screenshot (Cancelado/Activo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Cancelado', // Static for mockup match, in real life derive from status
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextMessage(ChatMessage message, bool mine) {
    final time = _formatTime(message.createdAt);
    final content = message.content ?? '';

    // Detect message type
    final isAudio = _isAudioMessage(content);
    final isImage = _isImageMessage(content);
    final url = isAudio || isImage ? _extractUrl(content) : null;

    final bubbleColor = mine ? AppTheme.colorPrimary : Colors.white;
    final textColor = mine ? Colors.white : Colors.black87;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ChambaNetworkAvatar(
                  url: widget.counterpartAvatarUrl,
                  radius: 14,
                  fallbackText: widget.counterpartName.trim().isEmpty ? '?' : widget.counterpartName.trim().substring(0, 1).toUpperCase(),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        widget.counterpartName,
                        style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!mine) _buildBubbleTail(isMine: false, color: bubbleColor),
                      Flexible(
                        child: Container(
                          padding: isImage
                              ? const EdgeInsets.all(4)
                              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.70,
                          ),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            boxShadow: mine ? [] : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(mine ? 20 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Audio message
                              if (isAudio && url != null)
                                _buildAudioPlayer(url, mine)
                              // Image message
                              else if (isImage && url != null)
                                _buildImagePreview(url)
                              // Text message
                              else
                                Text(
                                  content,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: textColor,
                                    height: 1.3,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: mine
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (mine) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (mine) _buildBubbleTail(isMine: true, color: bubbleColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String url, bool mine) {
    final isPlaying = _currentlyPlayingAudioUrl == url && _isPlayingAudio;
    final position =
        _currentlyPlayingAudioUrl == url ? _audioPosition : Duration.zero;
    final duration =
        _currentlyPlayingAudioUrl == url ? _audioDuration : Duration.zero;

    String formatDuration(Duration d) {
      final minutes = d.inMinutes.toString().padLeft(2, '0');
      final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    return GestureDetector(
      onTap: () => _playAudio(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: mine
              ? Colors.white.withOpacity(0.15)
              : AppTheme.colorPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: mine ? Colors.white : AppTheme.colorPrimary,
              size: 24,
            ),
            const SizedBox(width: 8),
            // Waveform simulation
            Container(
              width: 60,
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 3,
                    height: 8 + (index % 3) * 6,
                    decoration: BoxDecoration(
                      color: mine
                          ? Colors.white.withOpacity(0.6)
                          : AppTheme.colorPrimary.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatDuration(position) +
                  (duration > Duration.zero
                      ? ' / ${formatDuration(duration)}'
                      : ''),
              style: TextStyle(
                fontSize: 12,
                color:
                    mine ? Colors.white.withOpacity(0.8) : AppTheme.colorMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(String url) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ChambaNetworkImage(
          url: url,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildBubbleTail({required bool isMine, required Color color}) {
    return CustomPaint(
      painter: BubbleTailPainter(
        isMine: isMine,
        color: color,
      ),
      size: const Size(12, 20),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--:--';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  // WhatsApp-style date header methods
  bool _shouldShowDateHeader(int index) {
    if (index == 0) return true;
    if (_messages.isEmpty || index >= _messages.length) return false;

    final currentMessage = _messages[index];
    final previousMessage = _messages[index - 1];

    final currentDate = _dateOnly(currentMessage.createdAt);
    final previousDate = _dateOnly(previousMessage.createdAt);

    return currentDate != previousDate;
  }

  DateTime _dateOnly(DateTime? dateTime) {
    if (dateTime == null) return DateTime(0);
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  Widget _buildDateHeader(DateTime? dateTime) {
    if (dateTime == null) return const SizedBox.shrink();

    final label = _getDateLabel(dateTime);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6), // Light grey
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF), // Grey text
          ),
        ),
      ),
    );
  }

  String _getDateLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(messageDay).inDays;

    final List<String> weekDays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final List<String> months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    if (diff < 7) {
      // This week - show day name
      final weekdayIndex = dateTime.weekday - 1; // 1=Monday, 7=Sunday
      return weekDays[weekdayIndex];
    }

    // Older - show full date
    return '${dateTime.day} de ${months[dateTime.month - 1]}';
  }
}

// Custom painter for WhatsApp-style bubble tail
class BubbleTailPainter extends CustomPainter {
  final bool isMine;
  final Color color;

  BubbleTailPainter({required this.isMine, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isMine) {
      // Right tail (my messages)
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height * 0.3);
      path.quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.5,
        size.width * 0.2,
        size.height * 0.8,
      );
      path.lineTo(0, size.height);
      path.close();
    } else {
      // Left tail (other's messages)
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height * 0.3);
      path.quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.5,
        size.width * 0.8,
        size.height * 0.8,
      );
      path.lineTo(size.width, size.height);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
