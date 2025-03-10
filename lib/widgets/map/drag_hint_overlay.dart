import 'package:flutter/material.dart';

class DragHintOverlay extends StatelessWidget {
  final VoidCallback onGotIt;

  const DragHintOverlay({
    super.key,
    required this.onGotIt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Drag Map to Position Pin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Icon(
                  Icons.touch_app,
                  size: 48,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Drag the map to position the pin exactly where you want to report the issue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onGotIt,
                  child: const Text('Got It'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
