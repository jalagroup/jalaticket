import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart' show AppColors;

class SearchableDropdown<T> extends StatefulWidget {
  final String labelText;
  final String? hintText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String Function(T) getLabel;
  final bool showOtherOption;
  final VoidCallback? onOtherSelected;

  const SearchableDropdown({
    Key? key,
    required this.labelText,
    this.hintText,
    this.value,
    required this.items,
    this.onChanged,
    required this.getLabel,
    this.showOtherOption = false,
    this.onOtherSelected,
  }) : super(key: key);

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<DropdownMenuItem<T>> _filteredItems = [];
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _filteredItems = widget.items;
      if (_isOpen) _updateOverlay();
    }
  }

  void _filterItems(String query) {
    if (!mounted) return;
    _filteredItems = query.isEmpty
        ? widget.items
        : widget.items.where((item) {
            if (item.value == null) return false;
            return widget
                .getLabel(item.value as T)
                .toLowerCase()
                .contains(query.toLowerCase());
          }).toList();
    _updateOverlay();
  }

  void _toggleDropdown() => _isOpen ? _closeDropdown() : _openDropdown();

  void _openDropdown() {
    if (!mounted || _isOpen) return;
    _searchController.clear();
    _filteredItems = widget.items;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    if (mounted) setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    if (!_isOpen) return;
    _removeOverlay();
    if (mounted) setState(() => _isOpen = false);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.markNeedsBuild();
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    final l10n = AppLocalizations.safeOf(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return OverlayEntry(builder: (_) => const SizedBox.shrink());
    }
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeDropdown,
        child: Stack(
          children: [
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 6),
                child: GestureDetector(
                  onTap: () {},
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 320),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search bar
                            Container(
                              color: Colors.grey.shade50,
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: const TextStyle(fontSize: 13, height: 1.3),
                                decoration: InputDecoration(
                                  hintText: '${l10n.search}...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: Colors.grey.shade400,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: Colors.grey.shade500,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            _filterItems('');
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: _filterItems,
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey.shade100),
                            // Items list
                            Flexible(
                              child: _buildItemsList(l10n),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(AppLocalizations l10n) {
    final totalCount =
        _filteredItems.length + (widget.showOtherOption ? 1 : 0);

    if (totalCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            l10n.noResultsFound,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemCount: totalCount,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade100, indent: 14, endIndent: 14),
      itemBuilder: (context, index) {
        if (widget.showOtherOption && index == _filteredItems.length) {
          return _buildOtherOption(l10n);
        }
        return _buildItem(_filteredItems[index]);
      },
    );
  }

  Widget _buildItem(DropdownMenuItem<T> item) {
    final isSelected = item.value == widget.value;
    return InkWell(
      onTap: () {
        widget.onChanged?.call(item.value);
        _closeDropdown();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.07)
            : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 13.5,
                  color: isSelected ? AppColors.primary : Colors.black87,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: item.child,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherOption(AppLocalizations l10n) {
    return InkWell(
      onTap: () {
        _closeDropdown();
        widget.onOtherSelected?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.otherSpecify,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final hasValue = widget.value != null;
    final displayText = hasValue
        ? widget.getLabel(widget.value as T)
        : widget.hintText ?? '${l10n.select} ${widget.labelText}';

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            color: _isOpen
                ? AppColors.primary.withValues(alpha: 0.04)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isOpen ? AppColors.primary : Colors.grey.shade300,
              width: _isOpen ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 7),
                    Text(
                      widget.labelText,
                      style: TextStyle(
                        fontSize: 11,
                        color: _isOpen
                            ? AppColors.primary
                            : Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: hasValue ? Colors.black87 : Colors.grey.shade400,
                        fontWeight:
                            hasValue ? FontWeight.w500 : FontWeight.normal,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: _isOpen ? AppColors.primary : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
