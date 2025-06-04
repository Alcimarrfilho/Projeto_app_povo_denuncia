import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        // Pesquisa futura
        break;
      case 2:
        Navigator.pushNamed(context, '/new_denuncia');
        break;
      case 3:
        Navigator.pushNamed(context, '/status_denuncia');
        break;
      case 4:
        Navigator.pushNamed(context, '/conta');
        break;
    }
  }

  void _mostrarOpcoes(BuildContext context, DocumentSnapshot denuncia) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Opções'),
            content: const Text('O que você deseja fazer com esta denúncia?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/ver_denuncia',
                    arguments: denuncia,
                  );
                },
                child: const Text('Ver'),
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('denuncias')
                      .doc(denuncia.id)
                      .delete();
                  Navigator.pop(context);
                },
                child: const Text('Apagar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
    );
  }

  Widget _buildCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final titulo = data['titulo'] ?? '';
    final descricao = data['descricao'] ?? '';
    final status = data['status'] ?? 'Pendente';
    final dataHora = (data['data'] as Timestamp?)?.toDate();

    return GestureDetector(
      onTap: () => _mostrarOpcoes(context, doc),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),

          title: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(descricao),
              const SizedBox(height: 8),
              if (dataHora != null)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(dataHora),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Povo Denuncia'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('denuncias')
                .orderBy('data', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Nenhuma denúncia disponível.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildCard(docs[index]),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color.fromARGB(255, 0, 0, 0),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Recentes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Criar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Mensagens',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Conta'),
        ],
      ),
    );
  }
}
