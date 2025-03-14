import 'package:flutter/material.dart';

class LocationLoadingIndicator extends StatelessWidget {
  final String message;
  
  const LocationLoadingIndicator({
    super.key,
    this.message = "Getting your location..."
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 70,
      left: 0,
      right: 0,
      child: Center(
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
