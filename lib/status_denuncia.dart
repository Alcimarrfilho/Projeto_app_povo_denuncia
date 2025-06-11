import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Importação do pacote intl para formatação de data

class StatusDenunciaScreen extends StatefulWidget {
  const StatusDenunciaScreen({super.key});

  @override
  State<StatusDenunciaScreen> createState() => _StatusDenunciaScreenState();
}

class _StatusDenunciaScreenState extends State<StatusDenunciaScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser; // Variável para armazenar o usuário logado

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser; // Obtém o usuário atual ao iniciar a tela

    // Se não houver usuário logado, exibe uma mensagem e pode redirecionar
    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Garante que o widget ainda está montado antes de mostrar o SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Você precisa estar logado para ver suas denúncias.',
              ),
            ),
          );
          // Opcional: Descomente a linha abaixo para redirecionar para a tela de login
          // Navigator.pushReplacementNamed(context, '/login');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Exibe um CircularProgressIndicator se não houver usuário logado ainda
    // ou se estiver aguardando o redirecionamento inicial
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Status da Denúncia'),
          backgroundColor: Color.fromARGB(255, 240, 71, 4),
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // Removido 'const' do construtor da AppBar aqui - Esta AppBar também não precisa de const
      appBar: AppBar(
        title: const Text('Status da Denúncia'),
        backgroundColor: const Color.fromARGB(255, 240, 71, 4),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Stream para buscar denúncias onde 'userId' é igual ao ID do usuário logado
        // Ordena pelas denúncias mais recentes ('data' descendente)
        stream:
            FirebaseFirestore.instance
                .collection('denuncias')
                .where('userId', isEqualTo: _currentUser!.uid)
                .orderBy('data', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // print('Erro ao carregar denúncias: ${snapshot.error}'); // Este print gera aviso 'avoid_print'
            return Center(
              child: Text('Erro ao carregar denúncias: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Nenhuma denúncia encontrada no momento.'),
            );
          }

          // Se há dados, constrói a lista de denúncias
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var denuncia = snapshot.data!.docs[index];
              // Garante que os dados são um Map<String, dynamic>
              Map<String, dynamic> data =
                  denuncia.data()! as Map<String, dynamic>;

              // Extrai os dados da denúncia, fornecendo valores padrão se forem nulos
              String titulo = data['titulo'] ?? 'Sem Título';
              String descricao = data['descricao'] ?? 'Sem Descrição';
              String status = data['status'] ?? 'Desconhecido';
              String tipoDenuncia = data['tipoDenuncia'] ?? 'Não especificado';
              String? imagemUrl = data['imagemUrl'];
              Timestamp? timestamp = data['data'] as Timestamp?;
              String dataFormatada =
                  timestamp != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(
                        timestamp.toDate(),
                      ) // Formata a data
                      : 'Data desconhecida';

              // Tratamento de localização (opcional, pode ser exibido de forma mais amigável)
              Map<String, dynamic>? localizacaoData = data['localizacao'];
              String localizacaoStr = 'Não informada';
              if (localizacaoData != null) {
                double latitude = localizacaoData['latitude'];
                double longitude = localizacaoData['longitude'];
                localizacaoStr =
                    'Lat: ${latitude.toStringAsFixed(4)}, Long: ${longitude.toStringAsFixed(4)}';
              }

              // Determina a cor do status para melhor visualização
              Color statusColor;
              switch (status) {
                case 'Pendente':
                  statusColor = Colors.orange;
                  break;
                case 'Em Análise':
                  statusColor = Colors.blue;
                  break;
                case 'Resolvido':
                  statusColor = Colors.green;
                  break;
                case 'Rejeitado':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor =
                      Colors.grey; // Cor padrão para status desconhecido
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              titulo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow:
                                  TextOverflow.ellipsis, // Para títulos longos
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tipo: $tipoDenuncia', // Exibe o tipo de denúncia
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descricao,
                        style: const TextStyle(fontSize: 15),
                        maxLines:
                            3, // Limita a descrição para não ficar muito grande
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Exibe a imagem se houver uma URL válida
                      if (imagemUrl != null && imagemUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imagemUrl,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            // Tratamento de erro caso a imagem não carregue
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.broken_image,
                                size: 80,
                                color: Colors.grey,
                              );
                            },
                          ),
                        ),
                      if (imagemUrl != null && imagemUrl.isNotEmpty)
                        const SizedBox(height: 8),
                      Text(
                        'Localização: $localizacaoStr',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enviada em: $dataFormatada',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
