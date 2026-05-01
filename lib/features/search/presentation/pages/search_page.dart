import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/database/database_service.dart';
import '../../data/models/search_result.dart';
import '../widgets/result_item_card.dart';
import '../widgets/search_header.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SearchResult> _results = [];
  bool _isInitialized = false;
  bool _isSearching = false;
  String _initError = '';
  Timer? _debounce;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _dbService.initDatabase();
      if (mounted) {
        setState(() => _isInitialized = true);
        _focusNode.requestFocus();
      }
    } catch (e, st) {
      debugPrint('[InitError] $e\n$st');
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 150), () async {
      try {
        final rawResults = await _dbService.performSearch(query.trim());
        final results = rawResults.map((json) => SearchResult.fromJson(json)).toList();
        if (mounted) {
          setState(() {
            _results = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('[SearchError] $e');
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _clearSearch() {
    _controller.clear();
    _onSearchChanged('');
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
            _onSearchChanged(_controller.text);
          }
        },
        onError: (errorNotification) {
          debugPrint('Speech Error: $errorNotification');
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _controller.text = result.recognizedWords;
            });
            // Also trigger search dynamically while speaking if we want,
            // or just let the user see the text and wait for "done".
            _onSearchChanged(_controller.text);
          },
        );
      } else {
        debugPrint('Speech recognition not available');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _onSearchChanged(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SearchHeader(),
              _buildSearchBar(),
              _buildStatusBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Search anything…',
          prefixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14.0),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF10B981),
                    ),
                  ),
                )
              : const Icon(Icons.search_rounded, size: 20),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF6B7280), size: 18),
                  onPressed: _clearSearch,
                ),
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.redAccent : const Color(0xFF6B7280),
                  size: 20,
                ),
                onPressed: _listen,
              ),
            ],
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildStatusBar() {
    if (!_isInitialized || _results.isEmpty) return const SizedBox.shrink();
    
    final int totalMatches = _results.fold(0, (sum, item) => sum + item.occurrenceCount);
    
    return Padding(
      padding: const EdgeInsets.only(left: 26, right: 26, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_results.length} result${_results.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (totalMatches > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalMatches total matches',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // ── Error ──────────────────────────────────────────────────────────────
    if (_initError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text('Database Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(_initError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _initError = '');
                _init();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // ── Loading ────────────────────────────────────────────────────────────
    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             CircularProgressIndicator(
              color: Color(0xFF10B981),
              strokeWidth: 2.5,
            ),
             SizedBox(height: 18),
             Text(
              'Loading knowledge base…',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // ── Empty state ────────────────────────────────────────────────────────
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 48,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _controller.text.isEmpty
                  ? 'Start typing to search'
                  : 'No results for "${_controller.text}"',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    // ── Results ────────────────────────────────────────────────────────────
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: _results.length,
      itemBuilder: (context, index) => ResultItemCard(
        item: _results[index],
        index: index,
        onTap: () async {
          var url = _results[index].url;
          if (url.isNotEmpty) {
            final searchTerm = _controller.text.trim();
            if (searchTerm.isNotEmpty) {
              final words = searchTerm.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
              final textDirectives = words.map((w) => 'text=${Uri.encodeComponent(w)}').join('&');
              final fragment = '#:~:$textDirectives';
              if (url.contains('#')) {
                url = url.substring(0, url.indexOf('#')) + fragment;
              } else {
                url += fragment;
              }
            }
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not launch $url'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }
}
