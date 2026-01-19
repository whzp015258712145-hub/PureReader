import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const SplashScreen({super.key, required this.onAnimationComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Slow and elegant
    );

    // Breathing effect: 0.0 -> 0.9 -> 0.6 -> fade out
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.9), weight: 30), // Fade in
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 0.6), weight: 30), // Breathe out
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.8), weight: 20), // Breathe in slightly
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 20), // Fade out
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward().then((_) {
       widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            );
          },
          child: Image.asset(
            'assets/images/app_icon_square.png',
            width: 100, // Minimalist size
            height: 100,
          ),
        ),
      ),
    );
  }
}