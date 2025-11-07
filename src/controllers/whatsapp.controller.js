// src/controllers/whatsapp.controller.js

const crypto = require('crypto');
const WhatsAppService = require('../services/whatsapp.service');
const AIService = require('../services/ai.service');
const UserModel = require('../models/user.model');
const ProspectModel = require('../models/shop.prospect.model');

// --- DÉBUT DU LOGGER PERSONNALISÉ ---
const fs = require('fs');
const path = require('path');
const logFilePath = path.join(__dirname, '..', 'whatsapp_debug.log');

/**
 * Écrit un message de log dans le fichier whatsapp_debug.log
 * @param {string} message Le message à enregistrer
 */
const logToFile = (message) => {
    const timestamp = new Date().toISOString();
    const logMessage = `${timestamp} - ${message}\n`;
    try {
        fs.appendFileSync(logFilePath, logMessage, 'utf8');
    } catch (err) {
        console.error(`Échec de l'écriture dans le fichier log: ${err.message}`);
    }
};
// --- FIN DU LOGGER PERSONNALISÉ ---


// --- SÉCURITÉ : Récupération des Clés ---
const WEBHOOK_SECRET = process.env.WASENDER_WEBHOOK_SECRET;
const DEBUG_MODE_SKIP_SECURITY = (!WEBHOOK_SECRET || WEBHOOK_SECRET === 'VOTRE_SECRET_FOURNI_PAR_WASENDER');

/**
 * Fonction de sécurité : Vérifie la signature de Wasender.
 */
const verifyWasenderSignature = (signature, rawBody, secret) => {
    if (DEBUG_MODE_SKIP_SECURITY) {
        logToFile("ATTENTION SÉCURITÉ: Contournement de la vérification de signature (DEBUG_MODE_SKIP_SECURITY=true).");
        return true;
    }
    if (!secret || !signature) {
        logToFile("[ERREUR SÉCURITÉ] Secret ou Signature manquant.");
        return false;
    }
    
    const isMatch = (signature === secret);
    
    if (!isMatch) {
        logToFile(`[SIG VERIFY] ÉCHEC. Reçu: ${signature}. Attendu (Secret): ${secret}.`);
    } else {
        logToFile("[SIG VERIFY] Signature vérifiée avec succès !");
    }
    return isMatch;
};


/**
 * Fonction utilitaire pour vérifier l'identité de l'expéditeur dans la BD.
 */
const identifyUser = async (phoneNumber) => {
    let userInfo = { phoneNumber: phoneNumber, role: 'prospect_b2b', id: null, name: 'Nouveau Prospect', shopId: null };
    try {
        const user = await UserModel.findByPhoneNumber(phoneNumber); 
        if (user) {
            userInfo.role = user.role;
            userInfo.id = user.id;
            userInfo.name = user.name;
            return userInfo;
        }
        let prospect = await ProspectModel.findByPhoneNumber(phoneNumber);
        if(!prospect) {
            prospect = await ProspectModel.create({ phone_number: phoneNumber, last_contact_date: new Date() });
        }
        userInfo.id = prospect.id;
        userInfo.name = prospect.contact_name || 'Prospect';
        return userInfo;
    } catch (error) {
        logToFile(`[ID] Erreur lors de la vérification DB de l'utilisateur: ${error.message}`);
        return userInfo; 
    }
};


/**
 * Gère le Webhook Wasender (réception de messages et d'événements).
 */
const handleWebhook = async (req, res) => {
    
    logToFile("-----------------------------------------");
    logToFile(`[FLUX] Appel Webhook reçu.`);

    // 1. VÉRIFICATION DE SÉCURITÉ
    const signature = req.header('x-webhook-signature'); 
    const rawBody = req.rawBody; 

    if (!verifyWasenderSignature(signature, rawBody, WEBHOOK_SECRET)) {
        logToFile(`[ERREUR SÉCURITÉ] Signature Invalide. Blocage du message.`);
        return res.status(401).send('Unauthorized');
    }
    
    // 2. PARSING DE L'ÉVÉNEMENT
    let event;
    try {
        if (!rawBody || rawBody.length === 0) {
            logToFile("[FLUX] Corps de requête vide reçu (peut-être un test ping ?).");
            return res.status(200).send('Empty body received.');
        }
        event = JSON.parse(rawBody.toString('utf8'));
    } catch (e) {
        logToFile(`[ERREUR PARSING] Impossible de parser le JSON du rawBody: ${e.message}`);
        logToFile(`Contenu brut reçu: ${rawBody.toString('utf8')}`);
        return res.status(400).send('Bad Request: Invalid JSON');
    }

    logToFile(`[FLUX] Événement Wasender reçu et validé. Corps JSON complet: ${JSON.stringify(event, null, 2)}`);

    // --- DÉBUT DE LA CORRECTION MAJEURE ---

    // 3. FILTRE ET TRAITEMENT DES MESSAGES ENTRANTS
    
    // CORRECTION 1: Vérifier `event.event` au lieu de `event.type`
    const isMessageEvent = (event.event === 'messages.received' || event.event === 'messages.upsert');
    const isTestWebhook = (event.event === 'webhook.test'); // Corrigé ici aussi

    if (isTestWebhook) {
        logToFile("[FLUX] Événement de TEST reçu et validé avec succès !");
        return res.status(200).send('Webhook test validé avec succès.');
    }

    // On vérifie si c'est un événement de message
    if (isMessageEvent) {
        
        // CORRECTION 2: Extraire les données de la bonne structure JSON
        const messageData = event.data?.messages;
        if (!messageData) {
            logToFile("[FLUX] Événement ignoré (data.messages est manquant).");
            return res.status(200).send('Event ignored, no message data.');
        }

        const fromMe = messageData.key?.fromMe === true;
        if (fromMe) {
            logToFile("[FLUX] Événement ignoré (message 'fromMe').");
            return res.status(200).send('Event ignored, message from me.');
        }

        // Extraire le numéro de l'expéditeur
        let fromPhone = messageData.key?.cleanedParticipantPn || // Groupe
                          messageData.key?.cleanedSenderPn ||   // Message direct
                          messageData.remoteJid;                // Fallback
        
        if (!fromPhone) {
            logToFile("[FLUX] Événement ignoré (impossible de trouver le numéro de l'expéditeur).");
            return res.status(200).send('Event ignored, unknown sender.');
        }
        
        // Nettoyer le numéro (enlever @s.whatsapp.net)
        if (fromPhone.includes('@')) {
            fromPhone = fromPhone.split('@')[0];
        }

        // Extraire le contenu texte
        let messageText = null;
        if (messageData.message?.conversation) {
            // C'est un message texte simple (comme "Bonjour tonton")
            messageText = messageData.message.conversation;
        } else if (messageData.message?.imageMessage?.caption) {
            // C'est le caption d'une image (comme "Adorable ...")
            messageText = messageData.message.imageMessage.caption;
        }
        
        // Vérifier si on a du texte à traiter
        if (!messageText || messageText.trim() === "") {
            const messageType = Object.keys(messageData.message || {})[0] || 'inconnu';
            logToFile(`[FLUX] Événement ignoré (pas de contenu texte). Type de message reçu: ${messageType} (ex: reactionMessage, audioMessage, etc.)`);
            return res.status(200).send('Event ignored, no text content.');
        }
        
        // --- FIN DE LA CORRECTION MAJEURE ---

        // SI ON ARRIVE ICI, C'EST UN SUCCÈS !
        logToFile(`[FLUX] Message texte à traiter de ${fromPhone}: "${messageText}"`);

        try {
            // A. Identification de l'Expéditeur
            const userInfo = await identifyUser(fromPhone);
            
            logToFile(`[FLUX] Utilisateur DB trouvé/créé: ${userInfo.role}. Lancement de SAM...`);

            // B. Enregistrement
            await WhatsAppService.logConversation(fromPhone, messageText, 'INCOMING', userInfo.role, null, userInfo.shopId);
            
            // C. Lancement de l'IA
            const aiResult = await AIService.processRequest(userInfo, messageText);

            logToFile(`[FLUX] Réponse de SAM générée (Modèle: ${aiResult.model}). Envoi Wasender...`);

            // D. Envoi de la Réponse
            await WhatsAppService.sendText(fromPhone, aiResult.text, aiResult.model);
            logToFile(`[FLUX] Réponse envoyée avec succès. Traitement terminé.`);

            return res.status(200).send('Message processed by AI');

        } catch (error) {
            logToFile(`[ERREUR DE FLUX CRITIQUE] Le code a échoué dans le TRY/CATCH: ${error.message}`);
            try {
                await WhatsAppService.sendText(fromPhone, "Désolé, SAM rencontre une erreur interne. L'administrateur est notifié.");
            } catch (sendError) {
                logToFile(`[ERREUR CRITIQUE] Impossible même d'envoyer le message d'erreur: ${sendError.message}`);
            }
            return res.status(500).send('Internal error');
        }
    }
    
    // Si ce n'était ni un test, ni un message
    logToFile(`[FLUX] Événement non pertinent ignoré (event.event n'est pas 'messages.received' ou 'webhook.test'). Event: ${event.event}. Renvoi de 200 OK.`);
    return res.status(200).send('Webhook event received, no action taken');
};


module.exports = {
    handleWebhook
};