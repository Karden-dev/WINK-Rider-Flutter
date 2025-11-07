// src/controllers/whatsapp.controller.js

const crypto = require('crypto'); // Module pour la vérification de sécurité
const WhatsAppService = require('../services/whatsapp.service');
const AIService = require('../services/ai.service');
const UserModel = require('../models/user.model');
// const ShopModel = require('../models/shop.model'); // NE PAS TOUCHER - Supprimé
const ProspectModel = require('../models/shop.prospect.model'); // Assurez-vous que le chemin est correct

// --- SÉCURITÉ : Récupération des Clés ---
const WEBHOOK_SECRET = process.env.WASENDER_WEBHOOK_SECRET;

// --- DÉBOGAGE : Si le secret n'est pas défini, désactiver la vérification ---
const DEBUG_MODE_SKIP_SECURITY = (!WEBHOOK_SECRET || WEBHOOK_SECRET === 'VOTRE_SECRET_FOURNI_PAR_WASENDER');

/**
 * Fonction de sécurité : Vérifie la signature de Wasender.
 * (Version finale : comparaison de texte simple)
 */
const verifyWasenderSignature = (signature, rawBody, secret) => {
    if (DEBUG_MODE_SKIP_SECURITY) {
        console.warn("[ATTENTION SÉCURITÉ] Contournement de la vérification de signature (DEBUG_MODE_SKIP_SECURITY=true).");
        return true;
    }
    if (!secret || !signature) {
        console.error("[ERREUR SÉCURITÉ] Secret ou Signature manquant. Vérifiez .env et le nom de l'en-tête dans le code.");
        return false;
    }
    
    // CORRECTION FINALE : Wasender envoie le secret en clair.
    const isMatch = (signature === secret);
    
    if (!isMatch) {
        console.error(`[SIG VERIFY] ÉCHEC. Reçu: ${signature}. Attendu (Secret): ${secret}. (Vérifiez que le WEBHOOK_SECRET dans .env est correct)`);
    }
    return isMatch;
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

        // --- CORRECTION APPLIQUÉE ICI ---
        // 2. Vérification dans la table SHOPS (Marchands) - DÉSACTIVÉE
        // const shop = await ShopModel.findByPhoneNumber(phoneNumber); // Provoque le crash
        // if (shop) {
        //     userInfo.role = 'marchand'; 
        //     userInfo.shopId = shop.id;
        //     userInfo.name = shop.name;
        //     return userInfo;
        // }
        // --- FIN DE LA CORRECTION ---
        
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
        // NOTE: Le crash de "ShopModel.findByPhoneNumber" arrivait ici.
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
    console.log(`[FLUX] Appel Webhook reçu.`);

    // 1. VÉRIFICATION DE SÉCURITÉ
    const signature = req.header('x-webhook-signature'); 
    const rawBody = req.rawBody; 

    if (!verifyWasenderSignature(signature, rawBody, WEBHOOK_SECRET)) {
        console.error(`[ERREUR SÉCURITÉ] Signature Invalide. Blocage du message.`);
        return res.status(401).send('Unauthorized');
    }
    
    // 2. PARSING DE L'ÉVÉNEMENT
    const event = req.body;
    console.log(`[FLUX] Événement Wasender reçu et validé: ${event.type}`); 

    // 3. FILTRE ET TRAITEMENT DES MESSAGES ENTRANTS (Le Réactif)
    const isTextMessage = (event.type === 'messages.received' || event.type === 'messages.upsert') && 
                          event.data?.type === 'text' && 
                          event.data?.fromMe === false;
    
    const isTestWebhook = event.type === 'webhook.test';

    if (isTestWebhook) {
        console.log("[FLUX] Événement de TEST reçu et validé avec succès !");
        return res.status(200).send('Webhook test validé avec succès.');
    }

    if (isTextMessage) {
        
        const incomingMessage = event.data;
        const fromPhone = incomingMessage.from; 
        const messageText = incomingMessage.body;

        console.log(`[FLUX] Message texte à traiter de ${fromPhone}: "${messageText}"`);

        try {
            // A. Identification de l'Expéditeur
            const userInfo = await identifyUser(fromPhone);
            
            console.log(`[FLUX] Utilisateur DB trouvé/créé: ${userInfo.role}. Lancement de SAM...`);

            // B. Enregistrement et Traitement de l'Intelligence
            await WhatsAppService.logConversation(fromPhone, messageText, 'INCOMING', userInfo.role, null, userInfo.shopId);
            
            // C. Lancement de SAM
            const aiResult = await AIService.processRequest(userInfo, messageText);

            console.log(`[FLUX] Réponse de SAM générée (Modèle: ${aiResult.model}). Envoi Wasender...`);

            // D. Envoi de la Réponse de l'Agent
            await WhatsAppService.sendText(fromPhone, aiResult.text, aiResult.model);
            console.log(`[FLUX] Réponse envoyée avec succès. Traitement terminé.`);

            return res.status(200).send('Message processed by AI');

        } catch (error) {
            console.error(`[ERREUR DE FLUX CRITIQUE] Le code a échoué dans le TRY/CATCH:`, error);
            // On tente d'envoyer un message d'erreur si l'envoi lui-même n'a pas échoué
            try {
                await WhatsAppService.sendText(fromPhone, "Désolé, SAM rencontre une erreur interne. L'administrateur est notifié.");
            } catch (sendError) {
                console.error("[ERREUR CRITIQUE] Impossible même d'envoyer le message d'erreur:", sendError.message);
            }
            return res.status(500).send('Internal error');
        }
    }
    
    console.log("[FLUX] Événement non pertinent ignoré. Renvoi de 200 OK.");
    return res.status(200).send('Webhook event received, no action taken');
};


module.exports = {
    handleWebhook
};