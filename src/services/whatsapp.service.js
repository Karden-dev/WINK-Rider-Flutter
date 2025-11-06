// src/services/whatsapp.service.js

const { createWasender } = require('wasenderapi');

// Variable locale pour stocker la connexion DB qui sera injectée
let db;

// --- INITIALISATION DE L'API WASENDER ---
if (!process.env.WASENDER_API_KEY) {
    console.error("ERREUR FATALE: WASENDER_API_KEY n'est pas défini.");
}
const wasender = createWasender(process.env.WASENDER_API_KEY);

/**
 * Nettoie et formate un numéro de téléphone pour l'API Wasender.
 * (Exemple : supprime '+', s'assure qu'il commence par le code pays comme 237...)
 * @param {string} phone - Le numéro de téléphone (ex: '+237690123456' ou '690123456')
 * @returns {string} - Le numéro formaté (ex: '237690123456')
 */
const formatPhoneNumber = (phone) => {
    // Supprime les espaces, '+', et autres caractères non numériques
    let cleaned = phone.replace(/\D/g, '');
    
    // (Logique spécifique à WINK EXPRESS - à adapter si nécessaire)
    // Si le numéro commence par '6' et fait 9 chiffres (Cameroun), ajoutez le code pays
    if (cleaned.length === 9 && cleaned.startsWith('6')) {
        return '237' + cleaned;
    }
    // Si le numéro commence déjà par 237, c'est bon
    if (cleaned.length === 12 && cleaned.startsWith('237')) {
        return cleaned;
    }
    
    // Retourne le numéro nettoyé (cas par défaut)
    return cleaned;
};

/**
 * Loggue une conversation dans la base de données.
 */
const logConversation = async (phone_number, message_text, direction, sender_type = 'wink_agent_ai', ai_model = null, shop_id = null) => {
    if (!db) {
        console.error("Erreur: Le service WhatsApp n'est pas initialisé avec la DB.");
        return; 
    }
    try {
        const query = `
            INSERT INTO whatsapp_conversation_history 
            (recipient_phone, sender_type, message_direction, message_text, ai_model_used, shop_id)
            VALUES (?, ?, ?, ?, ?, ?)
        `;
        await db.execute(query, [ 
            phone_number,
            sender_type,
            direction,
            message_text,
            ai_model,
            shop_id
        ]);
    } catch (error) {
        console.error("Erreur critique lors de l'enregistrement de l'historique de conversation:", error);
    }
};


/**
 * Envoie un message texte via Wasender et loggue l'action.
 * C'est ici que l'erreur 422 se produit.
 */
const sendText = async (recipient_phone, message_text, ai_model = 'gemini-2.5-flash') => {
    
    // --- CORRECTION 422 : Nettoyage du numéro de téléphone ---
    const formattedPhone = formatPhoneNumber(recipient_phone);
    
    try {
        const textPayload = {
            messageType: "text",
            to: formattedPhone, // Utilisation du numéro nettoyé
            text: message_text,
        };

        // --- DEBUG 422 : Affiche le JSON envoyé à Wasender ---
        console.log(`[DEBOGAGE 422] Envoi du payload à Wasender: ${JSON.stringify(textPayload)}`);

        const result = await wasender.send(textPayload); 
        
        await logConversation(recipient_phone, message_text, 'OUTGOING', 'wink_agent_ai', ai_model);

        return result;

    } catch (error) {
        // --- DEBUG 422 : Capture de l'erreur d'envoi ---
        console.error(`[ERREUR 422] Échec d'envoi à ${formattedPhone}:`, error.message);
        // L'erreur 422 sera visible ici dans vos logs
        throw new Error(`Erreur d'envoi WhatsApp (Code 422 probable): ${error.message}`);
    }
};

/**
 * Initialise le service en injectant le pool de connexion DB.
 */
const init = (dbPool) => {
    console.log("[WhatsAppService] Initialisé avec la connexion DB.");
    db = dbPool; 
};

module.exports = {
    init, 
    sendText,
    logConversation,
};