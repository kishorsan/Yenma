import 'package:flutter/material.dart';

import '../../domain/debt.dart';

/// Suggestions are inline and only shown while editing the name, so they never
/// cover another field. Free-text names remain valid when nothing matches.
class PersonNameField extends StatefulWidget {
  const PersonNameField({
    super.key,
    required this.controller,
    required this.people,
    required this.label,
    required this.validator,
    this.enabled = true,
  });
  final TextEditingController controller;
  final List<String> people;
  final String label;
  final FormFieldValidator<String> validator;
  final bool enabled;
  @override
  State<PersonNameField> createState() => _PersonNameFieldState();
}

class _PersonNameFieldState extends State<PersonNameField> {
  final _focus = FocusNode();
  bool _showAll = false;
  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_textChanged);
  }

  @override
  void didUpdateWidget(covariant PersonNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_textChanged);
      widget.controller.addListener(_textChanged);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _textChanged() {
    _showAll = false;
    _refresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_textChanged);
    _focus.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = personNameKey(widget.controller.text);
    final matches = widget.people
        .where((name) => _showAll || personNameKey(name).contains(query))
        .toList();
    return TextFieldTapRegion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            validator: widget.validator,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: 'Choose a saved person or type a new name',
              suffixIcon: widget.people.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Show saved people',
                      onPressed: widget.enabled
                          ? () {
                              setState(() => _showAll = true);
                              _focus.requestFocus();
                            }
                          : null,
                      icon: const Icon(Icons.person_search_outlined),
                    ),
            ),
          ),
          if (widget.enabled && _focus.hasFocus && matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text(
                        'Saved people',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 168),
                      child: ListView.builder(
                        key: const ValueKey('person-suggestions'),
                        shrinkWrap: true,
                        primary: false,
                        itemCount: matches.length,
                        itemBuilder: (context, index) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_outline, size: 20),
                          title: Text(matches[index]),
                          onTap: () {
                            widget.controller.value = TextEditingValue(
                              text: matches[index],
                              selection: TextSelection.collapsed(
                                offset: matches[index].length,
                              ),
                            );
                            _focus.unfocus();
                          },
                        ),
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
