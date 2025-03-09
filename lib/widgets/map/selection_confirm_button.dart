import 'package:flutter/material.dart';

class SelectionConfirmButton extends StatelessWidget {
  final bool showHint;
  final VoidCallback onUseLocation;

  const SelectionConfirmButton({
    super.key,
    required this.showHint,
    required this.onUseLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          children: [
            // Instruction text
            if (showHint)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Text('Drag the map to move the pin'),
                  ],
                ),
              ),
            // Confirm button
            ElevatedButton.icon(
              onPressed: onUseLocation,
              icon: const Icon(Icons.check),
              label: const Text('Use This Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
