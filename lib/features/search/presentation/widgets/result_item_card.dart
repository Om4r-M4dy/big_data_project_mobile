import 'package:flutter/material.dart';
import '../../data/models/search_result.dart';

class ResultItemCard extends StatefulWidget {
  final SearchResult item;
  final int index;
  final VoidCallback onTap;

  const ResultItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
  });

  @override
  State<ResultItemCard> createState() => _ResultItemCardState();
}

class _ResultItemCardState extends State<ResultItemCard> {
  bool _isExpanded = false;

  List<TextSpan> _buildHighlightedText(
      String text, TextStyle baseStyle, TextStyle highlightStyle) {
    if (!text.contains('<b>') || !text.contains('</b>')) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    final parts = text.split('<b>');
    for (int i = 0; i < parts.length; i++) {
      if (i == 0) {
        if (parts[i].isNotEmpty) {
          spans.add(TextSpan(text: parts[i], style: baseStyle));
        }
      } else {
        final subParts = parts[i].split('</b>');
        if (subParts.isNotEmpty) {
          spans.add(TextSpan(text: subParts[0], style: highlightStyle));
          if (subParts.length > 1 && subParts[1].isNotEmpty) {
            spans.add(TextSpan(text: subParts[1], style: baseStyle));
          }
        }
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: const Color(0xFF10B981).withValues(alpha: 0.1),
          highlightColor: const Color(0xFF10B981).withValues(alpha: 0.05),
          onTap: () {
            FocusScope.of(context).unfocus();
            widget.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // URL row
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        size: 11,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.item.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Title
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: _buildHighlightedText(
                      widget.item.title,
                      const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                      const TextStyle(
                        backgroundColor: Color(0xFFFEF08A),
                        color: Color(0xFF1E293B),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // Snippet
                RichText(
                  maxLines: _isExpanded ? null : 2,
                  overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
                  text: TextSpan(
                    children: _buildHighlightedText(
                      widget.item.content,
                      const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.55,
                      ),
                      const TextStyle(
                        backgroundColor: Color(0xFFFEF08A),
                        color: Color(0xFF1E293B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Expand / Collapse button
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Show less' : 'More description',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
