import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum DenunciaStatus { pendente, emAnalise, resolvido, rejeitado, desconhecido }

// Extensão para mapear strings de status para o enum e cores
extension DenunciaStatusExtension on DenunciaStatus {
  String get name {
    if (this == DenunciaStatus.pendente) {
      return 'Em Análise';
    } else if (this == DenunciaStatus.emAnalise) {
      return 'No Local';
    } else if (this == DenunciaStatus.resolvido) {
      return 'Resolvido';
    } else if (this == DenunciaStatus.rejeitado) {
      return 'Rejeitado';
    } else {
      return 'Desconhecido';
    }
  }

  Color get color {
    if (this == DenunciaStatus.pendente) {
      return Colors.orange.shade400;
    } else if (this == DenunciaStatus.emAnalise) {
      return Colors.orange.shade400;
    } else if (this == DenunciaStatus.resolvido) {
      return Colors.green.shade400;
    } else if (this == DenunciaStatus.rejeitado) {
      return Colors.red.shade400;
    } else {
      return Colors.grey.shade400;
    }
  }

  static DenunciaStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pendente':
        return DenunciaStatus.pendente;
      case 'em análise':
        return DenunciaStatus.emAnalise;
      case 'resolvido':
        return DenunciaStatus.resolvido;
      case 'rejeitado':
        return DenunciaStatus.rejeitado;
      default:
        return DenunciaStatus.desconhecido;
    }
  }
}

// Widget para exibir a timeline do status
class DenunciaStatusTimeline extends StatelessWidget {
  final DenunciaStatus currentStatus;

  const DenunciaStatusTimeline({super.key, required this.currentStatus});

  // Define os passos da timeline
  final List<DenunciaStatus> statusSteps = const [
    DenunciaStatus.pendente,
    DenunciaStatus.emAnalise,
    DenunciaStatus.resolvido,
  ];

  @override
  Widget build(BuildContext context) {
    int currentIndex = statusSteps.indexOf(currentStatus);
    bool isRejected = currentStatus == DenunciaStatus.rejeitado;

    return Column(
      children: [
        // 1. Linha de Ícones e Nomes (Parte superior, agrupados verticalmente)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(statusSteps.length, (index) {
            bool isActive = index <= currentIndex;
            DenunciaStatus stepStatus = statusSteps[index];
            return Expanded(
              child: Column(
                // Agrupa Ícone e Nome para cada passo
                children: [
                  Icon(
                    _getIconForStatus(stepStatus), // Ícone para cada status
                    color:
                        isActive
                            ? Colors.orange.shade800
                            : Colors.grey.shade600, // Cor do ícone
                    size: 20, // Tamanho do ícone
                  ),
                  const SizedBox(height: 4), // Espaço entre ícone e nome
                  Text(
                    stepStatus.name, // Nome da extensão
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          isActive
                              ? Colors.orange.shade800
                              : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(
          height: 8,
        ), // Espaço entre os ícones/nomes e a linha/pontos

        Stack(
          alignment: Alignment.center, // Centraliza os filhos da Stack
          children: [
            // A linha horizontal contínua laranja
            Container(
              height: 2,
              color: Colors.orange.shade400,
              margin: const EdgeInsets.symmetric(
                horizontal: 10.0,
              ), // Margem para não encostar nas bordas
              width:
                  double
                      .infinity, // Garante que a linha ocupe toda a largura disponível
            ),
            // Linha de pontos circulares (posicionados sobre a linha)
            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceAround, // Distribui os pontos uniformemente
              children: List.generate(statusSteps.length, (index) {
                bool isActive = index <= currentIndex;
                return Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isActive
                            ? Colors.orange.shade400
                            : Colors.grey.shade300,
                    border: Border.all(
                      color:
                          isActive
                              ? Colors.orange.shade600
                              : Colors.grey.shade400,
                      width: 1,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        if (isRejected)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Chip(
              label: Text(
                currentStatus.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: currentStatus.color,
              avatar: Icon(
                _getIconForStatus(currentStatus),
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  // Função auxiliar para obter ícones baseados no status (usada para os ícones e para o chip rejeitado)
  IconData _getIconForStatus(DenunciaStatus status) {
    switch (status) {
      case DenunciaStatus.pendente:
        return Icons.search;
      case DenunciaStatus.emAnalise:
        return Icons.location_on;
      case DenunciaStatus.resolvido:
        return Icons.check_circle;
      case DenunciaStatus.rejeitado:
        return Icons.cancel;
      case DenunciaStatus.desconhecido:
        return Icons
            .help_outline; // Removido o 'default' para evitar advertência
    }
  }
}

class StatusDenunciaScreen extends StatefulWidget {
  const StatusDenunciaScreen({super.key});

  @override
  State<StatusDenunciaScreen> createState() => _StatusDenunciaScreenState();
}

class _StatusDenunciaScreenState extends State<StatusDenunciaScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;

    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Você precisa estar logado para ver suas denúncias.',
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Status da Denúncia'),
          backgroundColor: const Color.fromARGB(255, 240, 71, 4),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status da Denúncia'),
        backgroundColor: const Color.fromARGB(255, 240, 71, 4),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
            // log('Erro ao carregar denúncias: ${snapshot.error}'); // Removido
            return Center(
              child: Text('Erro ao carregar denúncias: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Nenhuma denúncia encontrada no momento.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var denuncia = snapshot.data!.docs[index];
              Map<String, dynamic> data =
                  denuncia.data()! as Map<String, dynamic>;

              String titulo = data['titulo'] ?? 'Sem Título';
              String statusString = data['status'] ?? 'Desconhecido';
              String? imagemUrl = data['imagemUrl'];

              DenunciaStatus currentDenunciaStatus =
                  DenunciaStatusExtension.fromString(statusString);

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
                      // Título da Denúncia (parte mais superior)
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1, // Limita o título a uma linha
                      ),
                      const SizedBox(height: 12), // Espaço após o título
                      // Imagem à esquerda e Timeline de Status à direita
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .center, // Centraliza verticalmente os itens da linha
                        children: [
                          // Imagem à esquerda (reduzida)
                          if (imagemUrl != null && imagemUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                imagemUrl,
                                height: 80, // Tamanho reduzido
                                width: 80, // Tamanho reduzido
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 80,
                                    width: 80,
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value:
                                            loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 80,
                                    width: 80,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                        size: 40,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (imagemUrl != null && imagemUrl.isNotEmpty)
                            const SizedBox(
                              width: 16,
                            ), // Espaço entre imagem e timeline
                          // Timeline de Status (lado direito da imagem)
                          Expanded(
                            // Garante que a timeline ocupe o espaço restante
                            child: DenunciaStatusTimeline(
                              currentStatus: currentDenunciaStatus,
                            ),
                          ),
                        ],
                      ),
                      // Remover espaços extras se a imagem não existir
                      if (imagemUrl == null || imagemUrl.isEmpty)
                        const SizedBox(height: 8),

                      // Sem descrição, tipo, data formatada, localização explicitamente aqui para simplificar
                      // Eles já foram removidos do _buildDenunciaCard
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
