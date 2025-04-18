import 'package:flutter/material.dart';

class BatchProgressIndicator extends StatelessWidget {
  final double progress;
  final bool showPercentage;
  final Color? color;
  final double height;

  const BatchProgressIndicator({
    Key? key,
    required this.progress,
    this.showPercentage = false,
    this.color,
    this.height = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        // Background
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),

        // Progress bar
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: height,
              width: constraints.maxWidth * (progress / 100),
              decoration: BoxDecoration(
                color: progressColor,
                borderRadius: BorderRadius.circular(height / 2),
                // Add gradient effect
                gradient: LinearGradient(
                  colors: [
                    progressColor,
                    progressColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                // Add animated stripe pattern
                backgroundBlendMode: BlendMode.lighten,
              ),
            );
          },
        ),

        // Percentage text
        if (showPercentage)
          Positioned.fill(
            child: Center(
              child: Text(
                '${progress.toInt()}%',
                style: TextStyle(
                  color: progress > 50 ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: height * 0.6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
