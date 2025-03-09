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
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Icon(Icons.touch_app, size: 48, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Drag the map to move',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Position the pin at your complaint location',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onGotIt,
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
