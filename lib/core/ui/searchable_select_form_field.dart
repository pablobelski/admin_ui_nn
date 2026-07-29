import 'package:flutter/material.dart';

class SearchableSelectOption {
  const SearchableSelectOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class SearchableSelectFormField extends StatefulWidget {
  const SearchableSelectFormField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.labelText,
    this.emptyLabel = '— Not selected —',
    this.helperText,
    this.enabled = true,
    this.maxVisibleOptions = 100,
  });

  final String value;
  final List<SearchableSelectOption> options;
  final ValueChanged<String?>? onChanged;
  final String labelText;
  final String emptyLabel;
  final String? helperText;
  final bool enabled;
  final int maxVisibleOptions;

  @override
  State<SearchableSelectFormField> createState() =>
      _SearchableSelectFormFieldState();
}

class _SearchableSelectFormFieldState extends State<SearchableSelectFormField> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _selectedLabel);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(SearchableSelectFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLabel = _labelForValue(oldWidget.value, oldWidget.options);
    final nextLabel = _selectedLabel;
    final selectedValueChanged = oldWidget.value != widget.value;
    final selectedLabelLoaded = widget.value.isNotEmpty &&
        oldLabel != nextLabel &&
        _textController.text == oldLabel;

    if ((selectedValueChanged || selectedLabelLoaded) &&
        _textController.text != nextLabel) {
      final currentText = _textController.text;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _selectedLabel != nextLabel ||
            _textController.text != currentText) {
          return;
        }
        _textController.value = TextEditingValue(
          text: nextLabel,
          selection: TextSelection.collapsed(offset: nextLabel.length),
        );
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _selectedLabel => _labelForValue(widget.value, widget.options);

  String _labelForValue(String rawValue, List<SearchableSelectOption> options) {
    final value = rawValue.trim();
    if (value.isEmpty) return '';
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value;
  }

  Iterable<SearchableSelectOption> _matchingOptions(
    TextEditingValue textEditingValue,
  ) {
    final query = textEditingValue.text.trim().toLowerCase();
    final allOptions = <SearchableSelectOption>[
      SearchableSelectOption(value: '', label: widget.emptyLabel),
      ...widget.options,
    ];

    if (query.isEmpty) {
      return allOptions.take(widget.maxVisibleOptions);
    }

    return allOptions.where((option) {
      final label = option.label.toLowerCase();
      final value = option.value.toLowerCase();
      return label.contains(query) || value.contains(query);
    }).take(widget.maxVisibleOptions);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<SearchableSelectOption>(
          textEditingController: _textController,
          focusNode: _focusNode,
          displayStringForOption: (option) => option.label,
          optionsBuilder: widget.enabled
              ? _matchingOptions
              : (_) => const Iterable<SearchableSelectOption>.empty(),
          onSelected: (option) {
            _textController.text = option.value.isEmpty ? '' : option.label;
            widget.onChanged?.call(option.value);
            _focusNode.unfocus();
          },
          fieldViewBuilder: (
            context,
            textEditingController,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              enabled: widget.enabled,
              decoration: InputDecoration(
                labelText: widget.labelText,
                helperText: widget.helperText,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: widget.value.isEmpty ? 'Show options' : 'Clear',
                  icon: Icon(
                    widget.value.isEmpty ? Icons.arrow_drop_down : Icons.clear,
                  ),
                  onPressed: widget.enabled
                      ? () {
                          if (widget.value.isEmpty) {
                            focusNode.requestFocus();
                            return;
                          }
                          textEditingController.clear();
                          widget.onChanged?.call('');
                        }
                      : null,
                ),
              ),
              onTap: () {
                if (textEditingController.text.isNotEmpty) {
                  textEditingController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: textEditingController.text.length,
                  );
                }
              },
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final material = Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          option.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );

            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: constraints.maxWidth,
                child: material,
              ),
            );
          },
        );
      },
    );
  }
}
