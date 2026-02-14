import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'models.dart';
import 'ollama_client.dart';
import 'database.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ChatState(),
      child: const OllamaChatApp(),
    ),
  );
}


class ChatState extends ChangeNotifier {
  final List<ChatSession> _sessions = [];
  String? _currentSessionId;
  final OllamaClient _client = OllamaClient();
  final AppDatabase _db = AppDatabase();
  String _selectedModel = 'llama3';
  List<String> _availableModels = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _connectionError;
  String? _pendingImageBase64;
  Future<void>? _initFuture;

  List<ChatSession> get sessions => _sessions;
  String? get currentSessionId => _currentSessionId;
  bool get isInitialized => _isInitialized;
  ChatSession? get currentSession => _sessions.isEmpty 
      ? null 
      : _sessions.firstWhere((s) => s.id == _currentSessionId, orElse: () => _sessions.first);
  
  List<ChatMessage> get messages => currentSession?.messages ?? [];
  String get selectedModel => _selectedModel;
  List<String> get availableModels => _availableModels;
  bool get isLoading => _isLoading;
  String? get connectionError => _connectionError;
  String? get pendingImageBase64 => _pendingImageBase64;

  ChatState() {
    _initFuture = _init();
  }

  Future<void> ensureInitialized() async {
    if (_initFuture != null) await _initFuture;
  }

  Future<void> _init() async {
    await _refreshModels();
    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final dbSessions = await _db.getAllSessions();
      final List<ChatSession> loaded = [];
      
      for (final s in dbSessions) {
        final messages = await _db.getMessagesForSession(s.id);
        loaded.add(ChatSession(
          id: s.id,
          title: s.title,
          createdAt: s.createdAt,
          messages: messages.map((m) => ChatMessage(
            id: m.id,
            role: m.role,
            content: m.content,
            images: m.images != null ? List<String>.from(jsonDecode(m.images!)) : null,
            timestamp: m.timestamp,
          )).toList(),
        ));
      }
      
      // Sort sessions by createdAt descending to keep most recent at top
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (loaded.isNotEmpty) {
        _sessions.clear();
        _sessions.addAll(loaded);
        _currentSessionId = _sessions.first.id;
      } else if (_sessions.isEmpty) {
        await createNewChat();
      }
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> createNewChat() async {
    final newSession = ChatSession(title: 'New Chat');
    _sessions.insert(0, newSession);
    _currentSessionId = newSession.id;
    
    await _db.insertSession(SessionsCompanion.insert(
      id: newSession.id,
      title: newSession.title,
      createdAt: newSession.createdAt,
    ));
    
    notifyListeners();
  }

  void selectSession(String id) {
    _currentSessionId = id;
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    await _db.deleteMessagesForSession(id);
    await _db.deleteSession(id);
    
    if (_currentSessionId == id) {
      _currentSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
      if (_currentSessionId == null) {
        await createNewChat();
      }
    }
    notifyListeners();
  }

  Future<void> renameSession(String id, String newTitle) async {
    await ensureInitialized();
    final session = _sessions.where((s) => s.id == id).firstOrNull;
    if (session != null) {
      session.title = newTitle;
      
      await _db.updateSessionTitle(id, newTitle);
      
      notifyListeners();
    }
  }

  Future<void> _refreshModels() async {
    _isLoading = true;
    _connectionError = null;
    notifyListeners();
    try {
      _availableModels = await _client.listModels();
      if (_availableModels.isNotEmpty) {
        if (!_availableModels.contains(_selectedModel)) {
          _selectedModel = _availableModels.first;
        }
      }
    } catch (e) {
      debugPrint('Error fetching models: $e');
      _connectionError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retryConnection() => _refreshModels();

  void setSelectedModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      _pendingImageBase64 = base64Encode(bytes);
      notifyListeners();
    }
  }

  void clearPendingImage() {
    _pendingImageBase64 = null;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty && _pendingImageBase64 == null) return;
    
    await ensureInitialized();
    if (_currentSessionId == null || _sessions.isEmpty) await createNewChat();

    final session = currentSession!;
    final List<String>? images = _pendingImageBase64 != null ? [_pendingImageBase64!] : null;
    final userMessage = ChatMessage(role: 'user', content: text, images: images);
    
    session.messages.add(userMessage);
    _pendingImageBase64 = null;
    notifyListeners(); // Refresh UI immediately to show user message

    // Save user message and handle background tasks
    _isLoading = true;
    notifyListeners();
    
    await _saveMessage(session.id, userMessage);
    
    // Auto-rename session if it's the first message
    if (session.messages.length == 1 && session.title == 'New Chat') {
      try {
        final newTitle = text.length > 30 ? '${text.substring(0, 27)}...' : text;
        await renameSession(session.id, newTitle);
      } catch (e) {
        debugPrint('Error renaming session: $e');
      }
    }

    // Add a placeholder assistant message that we will stream into
    final assistantMessage = ChatMessage(role: 'assistant', content: '');
    session.messages.add(assistantMessage);
    final assistantMessageIndex = session.messages.length - 1;
    
    try {
      await for (final chunk in _client.chatStream(_selectedModel, session.messages.sublist(0, assistantMessageIndex))) {
        final currentContent = session.messages[assistantMessageIndex].content;
        session.messages[assistantMessageIndex] = ChatMessage(
          id: session.messages[assistantMessageIndex].id,
          role: 'assistant',
          content: currentContent + chunk,
        );
        notifyListeners();
      }
      // Save final assistant message
      await _saveMessage(session.id, session.messages[assistantMessageIndex]);
    } catch (e) {
      session.messages[assistantMessageIndex] = ChatMessage(
        role: 'assistant',
        content: 'Error: Could not reach Ollama. Ensure it is running and CORS is configured.\n\n`$e`',
      );
      await _saveMessage(session.id, session.messages[assistantMessageIndex]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveMessage(String sessionId, ChatMessage message) async {
    await _db.insertMessage(MessagesCompanion.insert(
      id: message.id,
      sessionId: sessionId,
      role: message.role,
      content: message.content,
      images: drift.Value(message.images != null ? jsonEncode(message.images) : null),
      timestamp: message.timestamp,
    ));
  }

  Future<void> clearChat() async {
    if (_currentSessionId != null) {
      currentSession?.messages.clear();
      await _db.deleteMessagesForSession(_currentSessionId!);
      notifyListeners();
    }
  }
}

class OllamaChatApp extends StatelessWidget {
  const OllamaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GovGen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate-900
        cardColor: const Color(0xFF1E293B), // Slate-800
        dividerColor: Colors.white10,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    
    return Scaffold(
      drawer: const Sidebar(),
      appBar: AppBar(
        title: const Text('GovGen', 
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: state.clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !state.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? const WelcomeView()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: state.messages[index]);
                    },
                  ),
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Colors.blueAccent,
              ),
            ),
          if (state.pendingImageBase64 != null)
             _buildPendingImagePreview(state),
          _buildInputArea(state),
        ],
      ),
    );
  }

  Widget _buildPendingImagePreview(ChatState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(state.pendingImageBase64!),
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                onPressed: state.clearPendingImage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image_outlined, color: Colors.blueAccent),
              onPressed: state.isLoading ? null : state.pickImage,
              tooltip: 'Attach Image',
            ),
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.blueAccent),
              onPressed: state.isLoading ? null : () => _showModelSelectionBottomSheet(context, state),
              tooltip: 'Select Model',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 5,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Ask GovGen anything...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                  onSubmitted: (val) {
                    state.sendMessage(val);
                    _controller.clear();
                    _scrollToBottom();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: state.isLoading ? null : () {
                state.sendMessage(_controller.text);
                _controller.clear();
                _scrollToBottom();
              },
              icon: state.isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelSelectionBottomSheet(BuildContext context, ChatState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Select Model',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (state.availableModels.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No models available', style: TextStyle(color: Colors.white38)),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.availableModels.length,
                    itemBuilder: (context, index) {
                      final model = state.availableModels[index];
                      final isSelected = state.selectedModel == model;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.psychology_outlined,
                            color: isSelected ? Colors.blueAccent : Colors.white38,
                          ),
                        ),
                        title: Text(
                          model,
                          style: TextStyle(
                            color: isSelected ? Colors.blueAccent : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: Colors.blueAccent) 
                          : null,
                        onTap: () {
                          state.setSelectedModel(model);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar('A', Colors.indigoAccent),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.images != null && message.images!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(message.images!.first),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                      code: const TextStyle(
                        backgroundColor: Colors.black26,
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            _buildAvatar('U', Colors.blueGrey),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String label, Color color) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: color,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E293B)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 40, color: Colors.blueAccent),
                  const SizedBox(height: 12),
                  const Text('GovGen', 
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      state.createNewChat();
                      Navigator.pop(context); // Close drawer
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: state.sessions.length,
              itemBuilder: (context, index) {
                final session = state.sessions[index];
                final isSelected = session.id == state.currentSessionId;
                
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.blueAccent.withOpacity(0.1),
                  title: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.blueAccent : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    state.selectSession(session.id);
                    Navigator.pop(context); // Close drawer
                  },
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white38),
                    onSelected: (value) {
                      if (value == 'delete') {
                        state.deleteSession(session.id);
                      } else if (value == 'rename') {
                        _showRenameDialog(context, state, session);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (state.connectionError != null)
                   Text(state.connectionError!, 
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                const Text('Connected to Ollama', 
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ChatState state, ChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              state.renameSession(session.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.blueAccent),
          ),
          const SizedBox(height: 24),
          const Text('Ready to Chat', 
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Choose a model and start a conversation.', 
            style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
