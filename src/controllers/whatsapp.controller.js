// src/controllers/whatsapp.controller.js

const crypto = require('crypto'); // Module pour la vérification de sécurité
const WhatsAppService = require('../services/whatsapp.service');
const AIService = require('../services/ai.service');
const UserModel = require('../models/user.model');
const ShopModel = require('../models/shop.model');
const ProspectModel = require('../models/shop.prospect.model'); // Assurez-vous que le chemin est correct

// --- SÉCURITÉ : Récupération des Clés ---
const WEBHOOK_SECRET = process.env.WASENDER_WEBHOOK_SECRET;

// --- DÉBOGAGE : Si le secret n'est pas défini, désactiver la vérification ---
const DEBUG_MODE_SKIP_SECURITY = (!WEBHOOK_SECRET || WEBHOOK_SECRET === 'VOTRE_SECRET_FOURNI_PAR_WASENDER');

/**
 * Fonction de sécurité : Vérifie la signature HMAC-SHA256 de Wasender.
 */
const verifyWasenderSignature = (signature, rawBody, secret) => {
    // Si nous sommes en mode débogage ou si le secret est manquant, on autorise temporairement.
    if (DEBUG_MODE_SKIP_SECURITY) return true; 

    if (!secret || !signature) return false;

    // Standard de l'industrie : HMAC SHA256 (le plus probable pour Wasender)
    try {
        const hash = crypto.createHmac('sha256', secret)
                           .update(rawBody) 
                           .digest('hex');

        // Wasender pourrait envoyer la signature brute ou préfixée (ex: 'sha256=')
        const isMatch = signature === hash || signature === `sha256=${hash}`;
        
        // Utile pour le débogage de la signature
        if (!isMatch) {
            console.error(`[SIG VERIFY] ÉCHEC. Calculé: ${hash}. Reçu: ${signature}.`);
        }
        
        return isMatch;

    } catch (error) {
        console.error("[ERREUR SÉCURITÉ] Échec lors du calcul du hash HMAC:", error.message);
        return false;
    }
};


/**
 * Fonction utilitaire pour vérifier l'identité de l'expéditeur dans la BD.
 */
const identifyUser = async (phoneNumber) => {
    // Initialisation avec le rôle par défaut (Prospect B2B)
    let userInfo = { phoneNumber: phoneNumber, role: 'prospect_b2b', id: null, name: 'Nouveau Prospect', shopId: null };

    try {
        // 1. Vérification dans la table USERS (Livreurs/Admins)
        const user = await UserModel.findByPhoneNumber(phoneNumber); 
        if (user) {
            userInfo.role = user.role;
            userInfo.id = user.id;
            userInfo.name = user.name;
            return userInfo;
        }

        // 2. Vérification dans la table SHOPS (Marchands)
        const shop = await ShopModel.findByPhoneNumber(phoneNumber); 
        if (shop) {
            userInfo.role = 'marchand'; 
            userInfo.shopId = shop.id;
            userInfo.name = shop.name;
            return userInfo;
        }
        
        // 3. Vérification/Création dans la table PROSPECTS (Nouveau)
        let prospect = await ProspectModel.findByPhoneNumber(phoneNumber);
        if(!prospect) {
            // Créer le prospect s'il n'existe pas (pour la mémoire future)
            prospect = await ProspectModel.create({ phone_number: phoneNumber, last_contact_date: new Date() });
        }

        userInfo.id = prospect.id;
        userInfo.name = prospect.contact_name || 'Prospect';
        return userInfo;

    } catch (error) {
        // NOTE: Si le contrôleur arrive ici, la DB fonctionne mais une requête a échoué.
        console.error("[ID] Erreur lors de la vérification DB de l'utilisateur:", error.message);
        // On continue avec le rôle par défaut pour ne pas bloquer le chat
        return userInfo; 
    }
};


/**
 * Gère le Webhook Wasender (réception de messages et d'événements).
 */
const handleWebhook = async (req, res) => {
    
    console.log("-----------------------------------------");
    console.log(`[DEBOGAGE FLUX] Appel Webhook reçu.`);

    // 1. VÉRIFICATION DE SÉCURITÉ
    const signature = req.header('x-wasender-signature'); 
    const rawBody = req.rawBody; 

    if (!verifyWasenderSignature(signature, rawBody, WEBHOOK_SECRET)) {
        console.error(`[ERREUR SÉCURITÉ] Signature Invalide. Blocage du message.`);
        return res.status(401).send('Unauthorized');
    }
    
    // 2. PARSING DE L'ÉVÉNEMENT
    const event = req.body;
    console.log(`[DEBOGAGE FLUX] Type d'événement Wasender: ${event.type}`); 

    // 3. FILTRE ET TRAITEMENT DES MESSAGES ENTRANTS (Le Réactif)
    // Nous vérifions pour les types d'événements de réception de message
    const isTextMessage = (event.type === 'messages.received' || event.type === 'messages.upsert') && 
                          event.data?.type === 'text' && 
                          event.data?.fromMe === false; // S'assurer que le message n'est pas de nous

    if (isTextMessage) {
        
        const incomingMessage = event.data;
        const fromPhone = incomingMessage.from; 
        const messageText = incomingMessage.body;

        console.log(`[DEBOGAGE FLUX] Message texte à traiter de ${fromPhone}: "${messageText}"`);

        try {
            // A. Identification de l'Expéditeur
            const userInfo = await identifyUser(fromPhone);
            
            console.log(`[DEBOGAGE FLUX] Utilisateur DB trouvé/créé: ${userInfo.role}. Lancement de SAM...`);

            // B. Enregistrement et Traitement de l'Intelligence
            await WhatsAppService.logConversation(fromPhone, messageText, 'INCOMING', userInfo.role, null, userInfo.shopId);
            
            // C. Lancement de SAM
            const aiResult = await AIService.processRequest(userInfo, messageText);

            console.log(`[DEBOGAGE FLUX] Réponse de SAM générée (Modèle: ${aiResult.model}). Envoi Wasender...`);

            // D. Envoi de la Réponse de l'Agent
            await WhatsAppService.sendText(fromPhone, aiResult.text, aiResult.model);
            console.log(`[DEBOGAGE FLUX] Réponse envoyée avec succès. Traitement terminé.`);

            return res.status(200).send('Message processed by AI');

        } catch (error) {
            console.error(`[ERREUR DE FLUX CRITIQUE] Le code a échoué dans le TRY/CATCH:`, error);
            await WhatsAppService.sendText(fromPhone, "Désolé, SAM rencontre une erreur interne. L'administrateur est notifié.");
            return res.status(500).send('Internal error');
        }
    }
    
    console.log("[DEBOGAGE FLUX] Événement non texte ou non pertinent ignoré. Renvoi de 200 OK.");
    return res.status(200).send('Webhook event received, no action taken');
};


module.exports = {
    handleWebhook
};