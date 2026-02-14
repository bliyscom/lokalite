import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import 'models.dart';
import 'ollama_client.dart';
import 'database.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

class OhadaTheme {
  static const Color primary = Color(0xFF004D99); // Institutional Blue
  static const Color accent = Color(0xFFC5A059);  // Imperial Gold
  
  // Dark Theme
  static const Color background = Color(0xFF0A0F0C); // Black Slate
  static const Color surface = Color(0xFF1B241E);    // Dark Green Slate
  static const Color border = Colors.white12;

  // Light Theme
  static const Color lightBackground = Color(0xFFFDFBF7); // Parchment/Sand
  static const Color lightSurface = Color(0xFFF2EEE4);    // Muted Sand
  static const Color lightBorder = Colors.black12;
}

class GovGenLogo extends StatelessWidget {
  final double size;
  const GovGenLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GovGenPainter(),
      ),
    );
  }
}

class GovGenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer Gold Ring (Institutional Seal)
    final outerRingPaint = Paint()
      ..color = OhadaTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(center, radius * 0.9, outerRingPaint);

    // Inner Forest Green Fill
    final bgPaint = Paint()
      ..color = OhadaTheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.82, bgPaint);

    // Heraldic Shield Path
    final shieldPath = Path();
    final sw = size.width;
    final sh = size.height;
    shieldPath.moveTo(sw * 0.5, sh * 0.25); // Top center
    shieldPath.quadraticBezierTo(sw * 0.75, sh * 0.25, sw * 0.75, sh * 0.45);
    shieldPath.quadraticBezierTo(sw * 0.75, sh * 0.75, sw * 0.5, sh * 0.85); // Bottom tip
    shieldPath.quadraticBezierTo(sw * 0.25, sh * 0.75, sw * 0.25, sh * 0.45);
    shieldPath.quadraticBezierTo(sw * 0.25, sh * 0.25, sw * 0.5, sh * 0.25);
    shieldPath.close();

    final shieldPaint = Paint()
      ..color = OhadaTheme.accent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.03;
    canvas.drawPath(shieldPath, shieldPaint);

    // Digital Security Motif (Center Node)
    final nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, sw * 0.04, nodePaint);

    // Circuit lines coming from the node
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.015;
    
    canvas.drawLine(center, Offset(sw * 0.4, sh * 0.4), linePaint);
    canvas.drawLine(center, Offset(sw * 0.6, sh * 0.4), linePaint);
    canvas.drawLine(center, Offset(sw * 0.5, sh * 0.65), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (context) => ChatState(prefs),
      child: const OllamaChatApp(),
    ),
  );
}

class OllamaChatApp extends StatelessWidget {
  const OllamaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GovGen',
      themeMode: state.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: OhadaTheme.lightBackground,
        colorScheme: const ColorScheme.light(
          primary: OhadaTheme.primary,
          secondary: OhadaTheme.accent,
          surface: OhadaTheme.lightSurface,
        ),
        dividerColor: OhadaTheme.lightBorder,
        hintColor: Colors.black38,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: OhadaTheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          iconTheme: IconThemeData(color: OhadaTheme.accent),
        ),
        cardTheme: CardThemeData(
          color: OhadaTheme.lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: OhadaTheme.lightBorder),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: OhadaTheme.background,
        colorScheme: const ColorScheme.dark(
          primary: OhadaTheme.primary,
          secondary: OhadaTheme.accent,
          surface: OhadaTheme.surface,
        ),
        dividerColor: OhadaTheme.border,
        hintColor: Colors.white24,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          iconTheme: IconThemeData(color: OhadaTheme.accent),
        ),
        cardTheme: CardThemeData(
          color: OhadaTheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: OhadaTheme.border),
          ),
        ),
      ),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      body: Row(
        children: [
          if (!isMobile)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: state.isSidebarVisible ? 300 : 0,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: const Sidebar(),
            ),
          
          // Chat Pane - Only Expanded if it's visible. 
          // If Document Mode is on and Chat is hidden, this goes away.
          if (state.isChatVisible)
            const Expanded(child: ChatPage()),

          // Editor Pane
          if (!isMobile && state.isDocumentMode)
            state.isChatVisible 
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: 500,
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
                  ),
                  child: const DocumentEditor(),
                )
              : const Expanded(child: DocumentEditor()),
        ],
      ),
      drawer: isMobile ? const Sidebar() : null,
      endDrawer: isMobile && (state.isDocumentMode && !state.isChatVisible) 
          ? const Drawer(child: DocumentEditor()) 
          : null,
    );
  }
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
  bool _isSidebarVisible = true;
  bool _isDocumentMode = false;
  bool _isChatVisible = true;
  ThemeMode _themeMode = ThemeMode.dark;
  String? _connectionError;
  String? _pendingImageBase64;
  Future<void>? _initFuture;
  final SharedPreferences _prefs;
  final QuillController _documentController = QuillController.basic();

  List<ChatSession> get sessions => _sessions;
  String? get currentSessionId => _currentSessionId;
  bool get isInitialized => _isInitialized;
  bool get isSidebarVisible => _isSidebarVisible;
  bool get isDocumentMode => _isDocumentMode;
  bool get isChatVisible => _isChatVisible;
  ThemeMode get themeMode => _themeMode;
  QuillController get documentController => _documentController;
  ChatSession? get currentSession => _sessions.isEmpty 
      ? null 
      : _sessions.firstWhere((s) => s.id == _currentSessionId, orElse: () => _sessions.first);
  
  List<ChatMessage> get messages => currentSession?.messages ?? [];
  String get selectedModel => _selectedModel;
  List<String> get availableModels => _availableModels;
  bool get isLoading => _isLoading;
  String? get connectionError => _connectionError;
  String? get pendingImageBase64 => _pendingImageBase64;
  
  ChatState(this._prefs) {
    _loadThemeFromPrefs();
    _initFuture = _init();
  }

  void _loadThemeFromPrefs() {
    final themeIndex = _prefs.getInt('theme_mode');
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    }
  }

  Future<void> ensureInitialized() async {
    if (_initFuture != null) await _initFuture;
  }

  Future<void> _init() async {
    await _refreshModels();
    await _loadSessions();
  }

  void _extractInternalDocument(String content) {
    // Look for formal document patterns: 
    // - "To:", "Subject:", "Formal Letter", "Memorandum", 
    // - Or large blocks of text that look like a letter (Date, Salutation, Body, Closing)
    
    // Simple heuristic: if we see "Subject:" and "To:", or common letter starts
    final lowerContent = content.toLowerCase();
    final documentMarkers = [
      'subject:', 'to:', 'from:', 'dear ', 'objet:', 'à l\'attention de',
      'lettre de', 'memorandum', 'note de service'
    ];
    
    bool hasMarker = documentMarkers.any((m) => lowerContent.contains(m));
    
    if (hasMarker) {
      // If we find a code block marked with 'text' or 'markdown' or just a large block,
      // we extract it. For now, we'll try to extract the "cleanest" part.
      
      String extracted = content;
      
      // If the model wrapped it in a code block, strip the backticks
      final codeBlockMatch = RegExp(r'```(?:[a-zA-Z]*)?\n([\s\S]*?)```').firstMatch(content);
      if (codeBlockMatch != null) {
        extracted = codeBlockMatch.group(1) ?? content;
      }
      
      final cleanText = extracted.trim();
      if (_documentController.document.toPlainText().trim() != cleanText) {
        _documentController.document = Document()..insert(0, cleanText);
      }
      
      // Auto-open document mode if not already open and we have significant content
      if (!_isDocumentMode && extracted.length > 50) {
        _isDocumentMode = true;
      }
    }
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

  void toggleSidebar() {
    _isSidebarVisible = !_isSidebarVisible;
    notifyListeners();
  }

  void toggleDocumentMode() {
    _isDocumentMode = !_isDocumentMode;
    // If we're closing document mode, ensure chat is visible to avoid a blank screen
    if (!_isDocumentMode) {
      _isChatVisible = true;
    }
    notifyListeners();
  }

  void copyToEditor(String content) {
    _documentController.document = Document()..insert(0, content.trim());
    if (!_isDocumentMode) {
      _isDocumentMode = true;
    }
    notifyListeners();
  }

  void toggleChatVisibility() {
    _isChatVisible = !_isChatVisible;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    
    try {
      await _prefs.setInt('theme_mode', _themeMode.index);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
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
        final newContent = currentContent + chunk;
        session.messages[assistantMessageIndex] = ChatMessage(
          id: session.messages[assistantMessageIndex].id,
          role: 'assistant',
          content: newContent,
        );
        
        // Smart Extraction
        _extractInternalDocument(newContent);
        
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
    final isMobile = MediaQuery.of(context).size.width < 700;
    
    return Scaffold(
      appBar: AppBar(
        leading: isMobile ? null : IconButton(
          icon: Icon(state.isSidebarVisible ? Icons.menu_open : Icons.menu),
          onPressed: state.toggleSidebar,
          tooltip: 'Toggle Sidebar',
        ),
        title: Text('GOVGEN', 
          style: TextStyle(
            fontWeight: FontWeight.w900, 
            fontSize: 22, 
            letterSpacing: 2.0,
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
          )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(state.isDocumentMode ? Icons.article_rounded : Icons.article_outlined, color: OhadaTheme.accent),
            onPressed: state.toggleDocumentMode,
            tooltip: 'Toggle Document Mode',
          ),
          IconButton(
            icon: Icon(state.themeMode == ThemeMode.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: OhadaTheme.accent),
            onPressed: state.toggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: OhadaTheme.accent),
            onPressed: state.createNewChat,
            tooltip: 'New Chat',
          ),
          const SizedBox(width: 8),
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
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: OhadaTheme.accent,
                minHeight: 2,
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
      color: Theme.of(context).colorScheme.surface,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: OhadaTheme.accent, size: 20),
                    onPressed: state.isLoading ? null : state.pickImage,
                    tooltip: 'Attach Image',
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, color: OhadaTheme.accent, size: 20),
                    onPressed: state.isLoading ? null : () => _showModelSelectionBottomSheet(context, state),
                    tooltip: 'Select Model',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 5,
                  minLines: 1,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Consult Governor Intelligence...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      state.sendMessage(val);
                      _controller.clear();
                      _scrollToBottom();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: state.isLoading ? null : () {
                if (_controller.text.trim().isNotEmpty) {
                  state.sendMessage(_controller.text);
                  _controller.clear();
                  _scrollToBottom();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: state.isLoading ? Colors.white10 : OhadaTheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!state.isLoading)
                      BoxShadow(
                        color: OhadaTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: state.isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: OhadaTheme.accent))
                  : const Icon(Icons.send_rounded, color: OhadaTheme.accent, size: 24),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'MODEL SELECTION',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light 
                        ? OhadaTheme.primary 
                        : OhadaTheme.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (state.availableModels.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('NO MODELS DETECTED', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12, letterSpacing: 1)),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? OhadaTheme.primary : Theme.of(context).dividerColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.memory,
                            color: isSelected ? OhadaTheme.accent : Theme.of(context).hintColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          model.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? OhadaTheme.accent : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w400,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                        trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: OhadaTheme.accent, size: 20) 
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
            Column(
              children: [
                _buildAvatar('A', Colors.indigoAccent),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.input_rounded, size: 16, color: OhadaTheme.accent),
                  tooltip: 'Sync to Editor',
                  onPressed: () => context.read<ChatState>().copyToEditor(message.content),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? OhadaTheme.primary : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUser ? OhadaTheme.accent.withValues(alpha: 0.3) : Theme.of(context).dividerColor,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
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
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color, fontSize: 15, height: 1.5),
                    h1: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.displayLarge?.color, fontWeight: FontWeight.bold),
                    h2: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.displayMedium?.color, fontWeight: FontWeight.bold),
                    h3: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.displaySmall?.color, fontWeight: FontWeight.bold),
                    h4: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.headlineMedium?.color, fontWeight: FontWeight.bold),
                    h5: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.headlineSmall?.color, fontWeight: FontWeight.bold),
                    h6: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.bold),
                    em: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color, fontStyle: FontStyle.italic),
                    strong: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.bold),
                    listBullet: TextStyle(color: isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color),
                    code: TextStyle(
                      backgroundColor: isUser ? Colors.black12 : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                      color: isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: isUser ? Colors.black12 : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
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

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: const BoxDecoration(
              color: OhadaTheme.primary,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32)),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GovGenLogo(size: 64),
                  SizedBox(height: 16),
                  Text('GOVGEN', 
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  SizedBox(height: 4),
                  Text('Harmonized Legal Intelligence', 
                    style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: state.sessions.length,
              itemBuilder: (context, index) {
                final session = state.sessions[index];
                final isSelected = session.id == state.currentSessionId;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    selected: isSelected,
                    selectedTileColor: Theme.of(context).brightness == Brightness.light
                      ? OhadaTheme.primary.withValues(alpha: 0.1)
                      : OhadaTheme.primary.withValues(alpha: 0.5),
                    title: Text(
                      session.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected 
                            ? (Theme.of(context).brightness == Brightness.light ? Colors.black : OhadaTheme.accent)
                            : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w400,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onTap: () => state.selectSession(session.id),
                    trailing: isSelected ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: OhadaTheme.accent, size: 20),
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
                    ) : null,
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.transparent),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                if (state.connectionError != null)
                   Text(state.connectionError!, 
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text('SECURE LOCAL NODE', 
                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
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
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: OhadaTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const GovGenLogo(size: 100),
          ),
          const SizedBox(height: 32),
          const Text('PROTOCOL ENGAGED', 
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3)),
          const SizedBox(height: 12),
          Text('Awaiting Governor Directive for localized inference.', 
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13, letterSpacing: 1)),
          const SizedBox(height: 48),
          _buildQuickAction(context, 'INITIALIZE TRANSACTION ARCHIVE'),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(label, style: const TextStyle(color: OhadaTheme.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
    );
  }
}

class DocumentEditor extends StatelessWidget {
  const DocumentEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? OhadaTheme.surface : OhadaTheme.lightSurface,
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => state.toggleDocumentMode(),
            ),
            title: const Text(
              'INSTITUTIONAL DRAFT',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            actions: [
              IconButton(
                icon: Icon(state.isChatVisible ? Icons.open_in_full_rounded : Icons.close_fullscreen_rounded),
                tooltip: state.isChatVisible ? 'Focus Mode' : 'Show Chat',
                onPressed: () => state.toggleChatVisibility(),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  // Copy to clipboard logic
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          
          // Institutional Rich-Text Toolbar (Matching User Image)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? OhadaTheme.background : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: QuillSimpleToolbar(
                controller: state.documentController,
              ),
            ),
          ),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? OhadaTheme.background : OhadaTheme.lightBackground,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                   // Parchment Texture Overlay (Subtle)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.03,
                      child: Image.network(
                        'https://www.transparenttextures.com/patterns/parchment.png',
                        repeat: ImageRepeat.repeat,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: QuillEditor.basic(
                      controller: state.documentController,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
