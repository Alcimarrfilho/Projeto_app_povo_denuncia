import 'package:flutter/material.dart';

class StatusDenuncia extends StatelessWidget {
  const StatusDenuncia({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status da Denuncia')),
      body: const Center(child: Text('Nenhuma denúncia no momento.')),
    );
  }
}
