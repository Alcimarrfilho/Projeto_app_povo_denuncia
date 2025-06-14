import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // Importe para debugPrint

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentIndex = 0; // Para o BottomNavigationBar

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0: // Home - Denúncias (Feed principal)
        // Já está na tela principal, não faz nada
        break;
      case 1: // Buscar (Recentes / Pesquisa futura)
        if (!mounted) return; // Adicionado check de mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Funcionalidade de busca em desenvolvimento!'),
          ),
        );
        break;
      case 2: // Criar Denúncia
        Navigator.pushNamed(context, '/report'); // Rota para NewDenunciaScreen
        break;
      case 3: // Status (Mensagens / Status Denúncia)
        Navigator.pushNamed(
          context,
          '/status_denuncia',
        ); // Rota para StatusDenunciaScreen
        break;
      case 4: // Conta
        Navigator.pushNamed(context, '/conta');
        break;
    }
  }

  // Diálogo de opções (Editar, Excluir)
  void _mostrarOpcoes(BuildContext context, DocumentSnapshot denuncia) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Opções da Denúncia'),
            content: const Text('O que você deseja fazer com esta denúncia?'),
            actions: [
              // Botão "Editar" (agora também serve para "Ver Detalhes" já que o outro foi removido)
              TextButton(
                onPressed: () {
                  if (!mounted)
                    return; // ADIÇÃO: Verifica se o widget está montado
                  Navigator.pop(context); // Fecha o AlertDialog
                  Navigator.pushNamed(
                    context,
                    '/ver_editar_denuncia', // Rota unificada para ver/editar (aponta para MinhasDenuncias)
                    arguments:
                        denuncia, // Passa a denúncia para a tela de edição/visualização
                  );
                },
                child: const Text('Editar'),
              ),
              // Botão "Excluir" com confirmação
              TextButton(
                onPressed: () async {
                  if (!mounted)
                    return; // ADIÇÃO: Verifica se o widget está montado antes de operações assíncronas

                  Navigator.pop(
                    context,
                  ); // Fecha o AlertDialog inicial de opções

                  // Diálogo de confirmação antes de excluir
                  bool? confirmDelete = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Confirmar Exclusão'),
                        content: const Text(
                          'Tem certeza que deseja excluir esta denúncia?',
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'Excluir',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  // Se o usuário confirmou a exclusão
                  if (confirmDelete == true) {
                    try {
                      await _firestore
                          .collection('denuncias')
                          .doc(denuncia.id)
                          .delete();
                      // Opcional: Se a denúncia tiver imagem no Storage, você também pode excluí-la aqui.
                      if (denuncia['imagemUrl'] != null &&
                          (denuncia['imagemUrl'] as String).isNotEmpty) {
                        await FirebaseStorage.instance
                            .refFromURL(denuncia['imagemUrl'])
                            .delete();
                      }
                      if (!mounted)
                        return; // ADIÇÃO (LINHA 116): Verifica se o widget está montado antes de showSnackBar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Denúncia excluída com sucesso!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted)
                        return; // ADIÇÃO (LINHA 122): Verifica se o widget está montado antes de showSnackBar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Erro ao excluir denúncia: ${e.toString()}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      debugPrint(
                        'Erro ao excluir denúncia: $e',
                      ); // CORREÇÃO: Substituído print por debugPrint
                    }
                  }
                },
                child: const Text(
                  'Excluir',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              // Botão "Cancelar"
              TextButton(
                onPressed: () {
                  if (!mounted)
                    return; // ADIÇÃO: Verifica se o widget está montado
                  Navigator.pop(context); // Apenas fecha o AlertDialog
                },
                child: const Text('Cancelar'),
              ),
            ],
          ),
    );
  }

  // Widget para construir cada card de denúncia no feed com layout simplificado
  Widget _buildDenunciaCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String titulo = data['titulo'] ?? 'Denúncia sem título';
    final String? imageUrl = data['imagemUrl']; // URL da imagem
    final Timestamp? timestamp = data['data']; // Timestamp do Firestore

    DateTime? dataHora;
    if (timestamp != null) {
      dataHora = timestamp.toDate(); // Converte Timestamp para DateTime
    }

    return GestureDetector(
      onTap:
          () => _mostrarOpcoes(
            context,
            doc,
          ), // Ao clicar no card, exibe as opções
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(
            12.0,
          ), // Ajusta o preenchimento para um visual mais compacto
          child: Row(
            // Usa Row para alinhar a imagem à esquerda e o texto à direita
            children: [
              // Imagem à esquerda (reduzida)
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    imageUrl,
                    height: 60, // Altura reduzida
                    width: 60, // Largura reduzida
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        // Placeholder enquanto carrega
                        height: 60,
                        width: 60,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2, // Indicador de progresso menor
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        // Placeholder em caso de erro na imagem
                        height: 60,
                        width: 60,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 30,
                          ), // Ícone menor
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(width: 12), // Espaço entre a imagem e o texto
              // Título e Data/Hora
              Expanded(
                // Ocupa o espaço restante
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16, // Fonte ligeiramente menor
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1, // Restringe o título a uma linha
                      overflow:
                          TextOverflow
                              .ellipsis, // Adiciona "..." se o texto for muito longo
                    ),
                    const SizedBox(height: 4),
                    if (dataHora != null)
                      Text(
                        '${DateFormat('dd/MM/yyyy HH:mm').format(dataHora)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ), // Data/hora menor
                      ),
                  ],
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
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Minhas Denúncias'),
          backgroundColor: const Color.fromARGB(255, 240, 71, 4),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Você precisa estar logado para ver suas denúncias.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          Colors.grey[100], // Fundo levemente cinza para um visual mais moderno
      appBar: AppBar(
        title: const Text('Minhas Denúncias'), // Título claro da AppBar
        centerTitle: true,
        backgroundColor: const Color.fromARGB(
          255,
          240,
          71,
          4,
        ), // Cor consistente com seu tema
        foregroundColor: Colors.white,
        elevation: 1, // Leve sombra para a AppBar
        // Ações da AppBar foram removidas para evitar duplicação com BottomNavigationBar
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Filtra as denúncias para mostrar APENAS as do usuário logado
        stream:
            _firestore
                .collection('denuncias')
                .where('userId', isEqualTo: currentUser.uid)
                .orderBy(
                  'data',
                  descending: true,
                ) // Ordena pela data mais recente primeiro
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint(
              'Erro ao carregar denúncias: ${snapshot.error}',
            ); // Substituído print por debugPrint
            return Center(
              child: Text(
                'Erro ao carregar denúncias: ${snapshot.error.toString()}',
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Você ainda não tem denúncias. Use o botão "Criar" na barra inferior para fazer uma!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildDenunciaCard(docs[index]),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type:
            BottomNavigationBarType
                .fixed, // Garante que todos os itens são exibidos mesmo com muitos itens
        selectedItemColor: const Color.fromARGB(
          255,
          240,
          71,
          4,
        ), // Cor de destaque para o item selecionado
        unselectedItemColor: Colors.grey, // Cor para itens não selecionados
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Criar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Status', // Label 'Status' para a rota '/status_denuncia'
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Conta'),
        ],
      ),
    );
  }
}
