// src/services/ai.service.js

// Importation des SDKs et du service de communication
const { GoogleGenAI } = require('@google/genai');
const WhatsAppService = require('./whatsapp.service'); 

// Variable locale pour stocker la connexion DB qui sera injectée depuis app.js
let db;

// --- IMPORTATION DE TOUS LES MODÈLES DE DONNÉES (Le Catalogue d'Expertise) ---
// (Les imports restent les mêmes)
const UserModel = require('../models/user.model');
const ShopModel = require('../models/shop.model');
const OrderModel = require('../models/order.model');
const DebtModel = require('../models/debt.model');
const RemittanceModel = require('../models/remittance.model');
const CashModel = require('../models/cash.model');
const CashStatModel = require('../models/cash.stat.model');
const RidersCashModel = require('../models/riderscash.model');
const DashboardModel = require('../models/dashboard.model');
const ReportModel = require('../models/report.model');
const PerformanceModel = require('../models/performance.model');
const RiderModel = require('../models/rider.model');
const ScheduleModel = require('../models/schedule.model');
const MessageModel = require('../models/message.model.js');


// --- INITIALISATION DE GEMINI ET DÉFINITION DE LA PERSONNALITÉ (SYSTEM_INSTRUCTION) ---

// --- CORRECTION APPLIQUÉE ICI ---
// Nous devons récupérer la clé depuis process.env et la passer au constructeur
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
if (!GEMINI_API_KEY) {
    console.error("ERREUR FATALE: GEMINI_API_KEY n'est pas défini dans .env.");
}
// Passez la clé au constructeur
const ai = new GoogleGenAI(GEMINI_API_KEY); 
// --- FIN DE LA CORRECTION ---


const EXPERT_WINK_INSTRUCTION = `
Tu es "WinkDev Expert", un consultant spécialiste de l'écosystème WINK EXPRESS.
Tu as accès à toute la base de données via les modèles importés.
Ton rôle est de répondre avec précision, en t'appuyant sur les termes techniques et les structures de la base de données.

Connaissances Internes (winkdb): Tu connais les tables 'orders', 'shops', 'users', 'debts', et 'remittances'. Tu peux expliquer les colonnes comme 'packaging_price' ou 'debt_amount'.
Connaissances Externes: Tu peux proposer des axes d'amélioration sur la publicité Facebook, le marketing produit ou l'architecture logicielle.
Ton : Tes réponses doivent être professionnelles, techniques et orientées vers la solution. Utilise l'humour UNIQUEMENT si le contexte est positif.

Règles de Sécurité (Non-Négociables): 
1. Ne fournis JAMAIS le CA global à un 'livreur'.
2. Ne fournis JAMAIS les données d'un 'shop' à un autre 'shop'.
3. Valide toujours le 'rôle' de l'utilisateur avant de donner des données sensibles.
`;

/**
 * Fonction centrale pour le raisonnement de l'Agent IA (gestion des messages entrants).
 */
const processRequest = async (userInfo, userMessage) => {
    // Vérifie si la connexion DB a été initialisée
    if (!db) {
        console.error("Erreur: Le service IA n'est pas initialisé avec la DB.");
        return { text: "Erreur interne: Le service IA n'est pas connecté à la base de données.", model: 'error' };
    }
    
    // Si la clé Gemini n'est pas chargée, impossible de continuer.
    if (!GEMINI_API_KEY) {
         console.error("Erreur: Le service IA ne peut pas traiter la demande car GEMINI_API_KEY est manquante.");
         return { text: "Erreur interne: Le service IA n'est pas configuré (clé manquante).", model: 'error' };
    }

    // 1. DÉTERMINER LE MODÈLE (ROUTAGE DE MODÈLE pour optimiser les coûts)
    let modelToUse = 'gemini-2.5-flash-lite'; // Par défaut, modèle rapide et économique
    
    // Si la question nécessite une analyse complexe ou est posée par un admin, on monte en gamme (Pro)
    if (userInfo.role === 'admin' || 
        userMessage.toLowerCase().includes('chiffre d\'affaires') || 
        userMessage.toLowerCase().includes('analyse') ||
        userMessage.toLowerCase().includes('pub facebook')) {
        
        modelToUse = 'gemini-2.5-pro'; // Modèle le plus intelligent
    }

    // 2. PRÉPARATION DU CONTEXTE (Récupération des données pertinentes)
    let businessContext = {};
    
    // ... (Logiques de récupération de contexte) ...

    // 3. GÉNÉRATION DE LA RÉPONSE (Appel à Gemini)
    try {
        const fullPrompt = `
            MESSAGE UTILISATEUR: "${userMessage}"
            
            CONTEXTE DE L'UTILISATEUR: 
            Rôle: ${userInfo.role} (Nom: ${userInfo.name})
            Données Métier Disponibles: ${JSON.stringify(businessContext, null, 2)}
            
            En t'appuyant sur ta SYSTEM_INSTRUCTION et le CONTEXTE, génère une réponse experte et précise.
        `;
        
        // --- CORRECTION APPLIQUÉE ICI ---
        // Nous utilisons 'ai.getGenerativeModel' pour utiliser l'instance authentifiée
        const model = ai.getGenerativeModel({ 
            model: modelToUse,
            systemInstruction: EXPERT_WINK_INSTRUCTION,
        });
        
        const result = await model.generateContent(fullPrompt);
        const response = result.response; // Accéder à la réponse
        const text = response.text(); // Extraire le texte
        // --- FIN DE LA CORRECTION ---
        
        return { 
            text: text, 
            model: modelToUse 
        };

    } catch (error) {
        console.error(`Erreur d'appel API Gemini avec ${modelToUse}:`, error);
        return { 
            text: "Je suis désolé, je rencontre actuellement une erreur de raisonnement complexe. Veuillez réessayer.",
            model: modelToUse 
        };
    }
};

/**
 * Fonction d'utilité pour le script Agent Observateur (envois proactifs de rapports).
 */
const generateText = async (prompt, model = 'gemini-2.5-pro') => {
     if (!GEMINI_API_KEY) return "Erreur: Clé Gemini manquante.";
     
     try {
         // --- CORRECTION APPLIQUÉE ICI ---
         const generativeModel = ai.getGenerativeModel({ 
            model: model,
            systemInstruction: EXPERT_WINK_INSTRUCTION,
         });
         
         const result = await generativeModel.generateContent(prompt);
         const response = result.response;
         // --- FIN DE LA CORRECTION ---
         
        return response.text();
    } catch (error) {
        console.error(`Erreur de génération de texte proactif avec ${model}:`, error);
        return "Erreur lors de la génération du rapport par l'Agent IA.";
    }
};

/**
 * Initialise le service en injectant le pool de connexion DB.
 * Cette fonction DOIT être appelée depuis app.js.
 */
const init = (dbPool) => {
    console.log("[AIService] Initialisé avec la connexion DB.");
    db = dbPool; // Stocke la connexion localement
};

module.exports = {
    init, // Exporte la fonction d'initialisation
    processRequest,
    generateText,
};