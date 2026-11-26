import 'package:flutter/material.dart';

/// Asks for a name for a finished (non-match) run.
/// Pops with the new name on apply, or `null` on discard.
class RunNameDialog extends StatefulWidget {
  const RunNameDialog({
    super.key,
    required this.initialName,
    required this.seconds,
  });

  final String initialName;
  final int seconds;

  @override
  State<RunNameDialog> createState() => _RunNameDialogState();
}

class _RunNameDialogState extends State<RunNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(
          text: widget.initialName,
        )
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final String name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  // PopScope blocks Escape, so only the buttons close the dialog
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: _buildDialog(context),
  );

  Widget _buildDialog(BuildContext context) => AlertDialog(
    title: const Text('Name this run'),
    content: SizedBox(
      width: 350,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Run name',
            suffixText: '_${widget.seconds}sec',
            errorText: value.text.trim().isEmpty ? 'Name is required' : null,
          ),
          onSubmitted: (_) => _apply(),
        ),
      ),
    ),
    actions: [
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Discard'),
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => FilledButton(
          onPressed: value.text.trim().isEmpty ? null : _apply,
          child: const Text('Apply'),
        ),
      ),
    ],
  );
}
