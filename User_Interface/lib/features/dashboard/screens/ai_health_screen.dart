import 'package:flutter/material.dart';

class AiHealthScreen extends StatelessWidget {
  const AiHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Health'),
      ),
      body: const Center(
        child: Text('AI Health Analysis'),
      ),
    );
  }
}

