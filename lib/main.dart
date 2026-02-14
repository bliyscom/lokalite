import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'ollama_client.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ChatState(),
      child: const OllamaChatApp(),
    ),
  );
}

class ChatState extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final OllamaClient _client = OllamaClient();
  String _selectedModel = 'llama3';
  List<String> _availableModels = [];
  bool _isLoading = false;
  String? _connectionError;
  String? _pendingImageBase64;

  List<ChatMessage> get messages => _messages;
  String get selectedModel => _selectedModel;
  List<String> get availableModels => _availableModels;
  bool get isLoading => _isLoading;
  String? get connectionError => _connectionError;
  String? get pendingImageBase64 => _pendingImageBase64;

  ChatState() {
    _refreshModels();
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

    final List<String>? images = _pendingImageBase64 != null ? [_pendingImageBase64!] : null;
    final userMessage = ChatMessage(role: 'user', content: text, images: images);
    _messages.add(userMessage);
    _pendingImageBase64 = null;
    _isLoading = true;
    notifyListeners();

    // Add a placeholder assistant message that we will stream into
    final assistantMessageIndex = _messages.length;
    _messages.add(ChatMessage(role: 'assistant', content: ''));
    
    try {
      await for (final chunk in _client.chatStream(_selectedModel, _messages.sublist(0, assistantMessageIndex))) {
        final currentContent = _messages[assistantMessageIndex].content;
        _messages[assistantMessageIndex] = ChatMessage(
          role: 'assistant',
          content: currentContent + chunk,
        );
        notifyListeners();
      }
    } catch (e) {
      _messages[assistantMessageIndex] = ChatMessage(
        role: 'assistant',
        content: 'Error: Could not reach Ollama. Ensure it is running and CORS is configured.\n\n`$e`',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}

class OllamaChatApp extends StatelessWidget {
  const OllamaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ollama Chat',
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
        title: Text('Chat with ${state.selectedModel}', 
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
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
            child: state.messages.isEmpty
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
                    hintText: 'Ask Ollama anything...',
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
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1E293B)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 40, color: Colors.blueAccent),
                  SizedBox(height: 12),
                  Text('Ollama Web Chat', 
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Model Selection', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                if (state.availableModels.isEmpty && !state.isLoading) ...[
                  Text(state.connectionError ?? 'No models found. Is Ollama running?', 
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: state.retryConnection,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else if (state.isLoading && state.availableModels.isEmpty) ...[
                  const Center(child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: state.availableModels.contains(state.selectedModel) 
                          ? state.selectedModel 
                          : (state.availableModels.isNotEmpty ? state.availableModels.first : null),
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        items: state.availableModels.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) state.setSelectedModel(val);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Connected to localhost:11434', 
              style: TextStyle(color: Colors.white24, fontSize: 11)),
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
