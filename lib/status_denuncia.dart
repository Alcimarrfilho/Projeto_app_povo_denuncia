import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:developer'; // Importado para usar 'log' no lugar de 'debugPrint'

// Enumeração para os possíveis status da denúncia
enum DenunciaStatus {
  pendente,
  emAnalise,
  resolvido,
  rejeitado,
  desconhecido, // Para qualquer status não mapeado
}

// Extensão para mapear strings de status para o enum e cores
extension DenunciaStatusExtension on DenunciaStatus {
  String get name {
    // Usando if-else if para evitar "unreachable_switch_default" se todos os casos forem explicitamente tratados
    if (this == DenunciaStatus.pendente) {
      return 'Pendente';
    } else if (this == DenunciaStatus.emAnalise) {
      return 'Em Análise';
    } else if (this == DenunciaStatus.resolvido) {
      return 'Resolvido';
    } else if (this == DenunciaStatus.rejeitado) {
      return 'Rejeitado';
    } else {
      // Cobre DenunciaStatus.desconhecido
      return 'Desconhecido';
    }
  }

  Color get color {
    if (this == DenunciaStatus.pendente) {
      return Colors.orange.shade400;
    } else if (this == DenunciaStatus.emAnalise) {
      return Colors.blue.shade400;
    } else if (this == DenunciaStatus.resolvido) {
      return Colors.green.shade400;
    } else if (this == DenunciaStatus.rejeitado) {
      return Colors.red.shade400;
    } else {
      // Cobre DenunciaStatus.desconhecido
      return Colors.grey.shade400;
    }
  }

  // Mapeia uma string de status para o enum correspondente (método estático)
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
    // Determine o índice do status atual
    int currentIndex = statusSteps.indexOf(currentStatus);
    // Para status rejeitado, pode ser um ponto final, não necessariamente parte da linha linear.
    bool isRejected = currentStatus == DenunciaStatus.rejeitado;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(statusSteps.length, (index) {
              bool isActive = index <= currentIndex;
              DenunciaStatus stepStatus = statusSteps[index];

              return Expanded(
                child: Column(
                  children: [
                    // Círculo do passo
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isActive ? stepStatus.color : Colors.grey.shade300,
                        border: Border.all(
                          color:
                              isActive
                                  ? stepStatus.color
                                  : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _getIconForStatus(
                            stepStatus,
                          ), // Ícone para cada status
                          color: isActive ? Colors.white : Colors.grey.shade600,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Nome do status
                    Text(
                      stepStatus.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color:
                            isActive ? stepStatus.color : Colors.grey.shade600,
                      ),
                    ),
                    // Linha conectora (exceto para o último elemento)
                    if (index < statusSteps.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Container(
                          height: 2,
                          color:
                              isActive
                                  ? stepStatus.color
                                  : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          // Se for rejeitado, um selo separado pode ser exibido abaixo da linha principal
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
      ),
    );
  }

  // Função auxiliar para obter ícones baseados no status
  IconData _getIconForStatus(DenunciaStatus status) {
    switch (status) {
      case DenunciaStatus.pendente:
        return Icons.hourglass_empty;
      case DenunciaStatus.emAnalise:
        return Icons.search;
      case DenunciaStatus.resolvido:
        return Icons.check_circle;
      case DenunciaStatus.rejeitado:
        return Icons.cancel;
      case DenunciaStatus.desconhecido:
      default:
        return Icons.help_outline;
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
  User? _currentUser; // Variável para armazenar o usuário logado

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser; // Obtém o usuário atual ao iniciar a tela

    // Se não houver usuário logado, exibe uma mensagem e pode redirecionar
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
          // Opcional: Descomente a linha abaixo para redirecionar para a tela de login
          // Navigator.pushReplacementNamed(context, '/login');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Exibe um CircularProgressIndicator se não houver usuário logado ainda
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
            log(
              'Erro ao carregar denúncias: ${snapshot.error}',
            ); // Substituído debugPrint por log
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
              String statusString = data['status'] ?? 'Desconhecido';
              String tipoDenuncia = data['tipoDenuncia'] ?? 'Não especificado';
              String? imagemUrl =
                  data['imagemUrl']; // **IMAGEMURL: Aqui a variável está correta.**
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

              // Chamar fromString a partir da extensão, não diretamente do enum.
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
                      // Título da Denúncia (na parte mais superior do card)
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),

                      // Conteúdo principal: Imagem à Esquerda, Detalhes e Status à Direita
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start, // Alinha itens ao topo da Row
                        children: [
                          // Imagem à esquerda (reduzida)
                          if (imagemUrl != null &&
                              imagemUrl
                                  .isNotEmpty) // **IMAGEMURL: Correção aqui**
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                imagemUrl, // **IMAGEMURL: Correção aqui**
                                height: 100, // Imagem reduzida
                                width: 100, // Imagem reduzida
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 100,
                                    width: 100,
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
                                    height: 100,
                                    width: 100,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                        size: 50,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (imagemUrl != null && imagemUrl.isNotEmpty)
                            const SizedBox(
                              width: 16,
                            ), // Espaço entre imagem e texto/status
                          // Detalhes e Status Chip (à direita da imagem)
                          Expanded(
                            // Ocupa o restante do espaço horizontal
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tipo de Denúncia e Status Chip na mesma linha
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tipo: $tipoDenuncia',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    // Selo de status (chip) - à direita
                                    Chip(
                                      label: Text(
                                        currentDenunciaStatus.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      backgroundColor:
                                          currentDenunciaStatus.color,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dataFormatada, // Data/Hora da denúncia
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  descricao,
                                  style: const TextStyle(fontSize: 15),
                                  maxLines: 4, // Limita a descrição
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Localização: $localizacaoStr',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey,
                      ), // Divisor visual
                      // Timeline de Status (parte inferior do card)
                      DenunciaStatusTimeline(
                        currentStatus: currentDenunciaStatus,
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
