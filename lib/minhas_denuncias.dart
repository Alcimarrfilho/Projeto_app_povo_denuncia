import 'package:flutter/material.dart';

class MinhasDenunciasScreen extends StatelessWidget {
  const MinhasDenunciasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Denúncias')),
      body: const Center(
        child: Text('Aqui serão listadas as denúncias feitas com seus status.'),
      ),
    );
  }
}
