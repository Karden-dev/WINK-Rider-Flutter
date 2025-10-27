// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../utils/app_theme.dart';
// TODO: Importer le modèle Message et le service WebSocket/Chat
// import '../models/message.dart';
// import '../services/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  final Order order;

  const ChatScreen({super.key, required this.order});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // TODO: Remplacer par un FutureBuilder et un List<Message> du service
  final List<Map<String, dynamic>> _mockMessages = [
    {'id': 1, 'content': 'Bonjour, la livraison est en cours. Arrivée dans 10 min.', 'is_sent': true, 'time': DateTime.now().subtract(const Duration(minutes: 5))},
    {'id': 2, 'content': 'Le client est injoignable au numéro fourni. Que faire ?', 'is_sent': true, 'time': DateTime.now().subtract(const Duration(minutes: 4))},
    {'id': 3, 'content': 'Veuillez essayer le 699 XXX XXX. Le colis est urgent.', 'is_sent': false, 'time': DateTime.now().subtract(const Duration(minutes: 2))},
    {'id': 4, 'content': 'Le client a demandé une modification d\'adresse.', 'is_sent': true, 'time': DateTime.now().subtract(const Duration(minutes: 1))},
  ];


  @override
  void initState() {
    super.initState();
    // TODO: Initialiser la connexion WebSocket (JOIN_CONVERSATION)
    // WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    // TODO: Quitter la conversation (LEAVE_CONVERSATION)
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Fonction de défilement automatique
  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // TODO: Remplacer par la logique d'envoi WebSocket
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _mockMessages.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'content': text,
        'is_sent': true,
        'time': DateTime.now(),
      });
    });

    _messageController.clear();
    // Déclenche le défilement après que le widget a été reconstruit
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }
  
  // TODO: Remplacer par la logique d'ajout de message rapide
  void _addQuickReply(String reply) {
    _messageController.text = _messageController.text.isEmpty ? reply : '${_messageController.text} $reply';
    _messageController.selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));
  }
  
  // Fonction pour afficher la demande de modification (basé sur rider-common.js)
  void _requestModification() {
    const prefix = "Demande de modification : ";
    const detailedMessage = prefix + "Veuillez préciser ici l'erreur (client, adresse, articles, montant...).";
    
    // Remplir le champ de saisie
    _messageController.text = detailedMessage;
    
    // Déplace le curseur au début de la zone de saisie du détail
    _messageController.selection = TextSelection.fromPosition(TextPosition(offset: prefix.length));

    // Afficher un message info
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Précisez la modification et envoyez.'), duration: Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - Commande #${widget.order.id}'),
        actions: [
          // Bouton Demander Modif. (similaire à rider-common.js/suivis.js)
          TextButton.icon(
            onPressed: _requestModification,
            icon: const Icon(Icons.edit_note, color: Colors.white),
            label: const Text('Demander Modif.', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // --- Zone de Messages ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              itemCount: _mockMessages.length,
              itemBuilder: (context, index) {
                final message = _mockMessages[index];
                return _buildMessageBubble(context, message);
              },
            ),
          ),
          
          // --- Messages Rapides (Quick Replies) - Inspiré de rider-common.js ---
          _buildQuickReplyArea(),

          // --- Zone de Saisie ---
          _buildInputArea(),
        ],
      ),
    );
  }
  
  // Widget pour une bulle de message (Inspiré du CSS de suivis.html/rider-common.js)
  Widget _buildMessageBubble(BuildContext context, Map<String, dynamic> message) {
    final isSent = message['is_sent'] as bool;
    final content = message['content'] as String;
    final time = message['time'] as DateTime;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isSent ? AppTheme.primaryColor : Colors.white, // Corail pour envoyé, Blanc pour reçu
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isSent ? 15 : 5), // Angle droit si reçu
            bottomRight: Radius.circular(isSent ? 5 : 15), // Angle droit si envoyé
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isSent ? Colors.white : AppTheme.secondaryColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                DateFormat('HH:mm').format(time),
                style: TextStyle(
                  fontSize: 10,
                  color: isSent ? Colors.white.withOpacity(0.7) : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget pour la zone des messages rapides
  Widget _buildQuickReplyArea() {
    // Liste des messages rapides (similaire à ceux chargés par suivis.js/rider-common.js)
    final quickReplies = ['Appel en cours', 'Client injoignable', 'J\'arrive dans 5 min', 'Je déclare un retour', 'Montant à vérifier'];
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: Colors.grey.shade100, // Couleur de fond neutre
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: quickReplies.map((reply) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ActionChip(
              label: Text(reply, style: TextStyle(fontSize: 12, color: AppTheme.secondaryColor)),
              backgroundColor: Colors.white,
              shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
              onPressed: () => _addQuickReply(reply),
            ),
          )).toList(),
        ),
      ),
    );
  }

  // Widget pour la zone de saisie
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'Écrire un message...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton d'envoi (Corail)
          FloatingActionButton(
            onPressed: _sendMessage,
            mini: true,
            backgroundColor: AppTheme.primaryColor,
            elevation: 0,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}