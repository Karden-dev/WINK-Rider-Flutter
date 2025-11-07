// src/scripts/aiAgentWatcher.js

// Importe les services (ils sont initialisés par app.js)
const AIService = require('../services/ai.service'); 
const WhatsAppService = require('../services/whatsapp.service');

// --- IMPORTATION DE TOUS LES MODÈLES DE DONNÉES (Expertise Totale) ---
// Note : Ces modèles sont utilisables car ils sont initialisés par app.js.
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

// Variable locale pour stocker la connexion DB qui sera injectée
let db;

// --- CONFIGURATION DU MOTEUR ---
const WATCH_INTERVAL_MS = 60000; // Intervalle de surveillance : 1 minute
const LAST_RUN_CACHE = {}; // Cache pour éviter le spam des tâches planifiées

// Le lien de l'avis doit être lu depuis les variables d'environnement
const GOOGLE_REVIEW_LINK = process.env.GOOGLE_REVIEW_LINK || "https://g.page/r/CfS3u_RgUC3lEBI/review";
const FACEBOOK_REVIEW_LINK = process.env.FACEBOOK_REVIEW_LINK || "https://facebook.com/WinkExpresss/reviews";


/**
 * 1. INSTRUCTION D'ACTION N°1 : 
 * Envoyer le rapport de performance hebdomadaire aux administrateurs (Mardi 9h00).
 */
const checkPerformanceReports = async () => {
    if (!db) return; 

    const today = new Date();
    const isTuesday = today.getDay() === 2; // 0=Dimanche, 1=Lundi, 2=Mardi
    const isAfter9AM = today.getHours() >= 9;
    const cacheKey = `performance_report_${today.getFullYear()}-${today.getMonth()}-${today.getDate()}`;

    if (isTuesday && isAfter9AM && !LAST_RUN_CACHE[cacheKey]) {
        console.log("[AI Watcher] Déclenchement du rapport de performance hebdomadaire (Mardi 9h).");
        
        try {
            const performanceData = { deliveries: 100, failures: 5, objective: 120 }; // Données de test
            
            const prompt = `
                Génère un rapport de supervision pour les administrateurs WINK EXPRESS.
                Données de la semaine : ${JSON.stringify(performanceData)}.
                Objectif: 750 livraisons.
                Le rapport doit inclure l'objectif et des 'impressions' sur les chiffres.
                Le ton doit être professionnel, avec une note d'humour si les chiffres sont excellents.
            `;
            const aiReportText = await AIService.generateText(prompt, 'gemini-2.5-pro');

            const admins = await UserModel.findUsersByRole('admin');
            
            for (const admin of admins) {
                await WhatsAppService.sendText(admin.phone_number, aiReportText, 'gemini-2.5-pro');
            }
            
            LAST_RUN_CACHE[cacheKey] = true;
            console.log("[AI Watcher] Rapport de performance envoyé avec succès aux administrateurs.");

        } catch (error) {
            console.error("[AI Watcher] Erreur lors de l'envoi du rapport de performance:", error);
        }
    }
};

/**
 * 2. INSTRUCTION D'ACTION N°2 : 
 * Surveille les commandes livrées pour envoyer les demandes d'avis Google/Facebook.
 */
const checkDeliveredOrdersForReview = async () => {
    if (!db) return; 

    try {
        // NOTE: La colonne 'ai_review_sent' doit être ajoutée manuellement à la table 'orders'.
        const [ordersToNotify] = await db.execute(
            `SELECT id, customer_phone, customer_name, deliveryman_id 
             FROM orders 
             WHERE status = 'delivered' 
               AND (ai_review_sent = 0 OR ai_review_sent IS NULL)
               -- FILTRE CRITIQUE : UNIQUEMENT les commandes livrées AUJOURD'HUI
               AND DATE(updated_at) = CURDATE() 
             LIMIT 50`
        );

        for (const order of ordersToNotify) {
            // Demande à l'IA de générer le message en incluant les deux liens
            const prompt = `
                Génère une demande d'avis polie pour le client ${order.customer_name} dont la commande est livrée.
                Propose de laisser un avis sur Google ou Facebook.
                Lien Google: ${GOOGLE_REVIEW_LINK}
                Lien Facebook: ${FACEBOOK_REVIEW_LINK}
            `;
            const aiMessage = await AIService.generateText(prompt, 'gemini-2.5-flash-lite');

            await WhatsAppService.sendText(order.customer_phone, aiMessage, 'gemini-2.5-flash-lite');
            
            // Marquer l'action dans la BD
            await db.execute("UPDATE orders SET ai_review_sent = 1 WHERE id = ?", [order.id]);
        }
    } catch (error) {
        // Log de l'erreur : cela continuera tant que la colonne n'est pas ajoutée.
        console.error("[AI Watcher] Erreur lors de la vérification des commandes livrées (Action requise: Ajouter colonne 'ai_review_sent'):", error.message);
    }
};


/**
 * Fonction principale du moteur qui tourne en boucle.
 */
const runAgentCycle = async () => {
    if (!db) {
        return;
    }
    
    await checkPerformanceReports();
    await checkDeliveredOrdersForReview();
};


/**
 * Initialise le service en injectant le pool de connexion DB et démarre le moteur.
 */
const init = (dbPool) => {
    console.log("[AIWatcher] Initialisé avec la connexion DB.");
    db = dbPool; 
    
    if (process.env.NODE_ENV !== 'test') {
        setInterval(runAgentCycle, WATCH_INTERVAL_MS); 
        console.log(`[WinkDev Expert] Agent Observateur démarré. Intervalle: ${WATCH_INTERVAL_MS / 1000}s.`);
    }
};

module.exports = {
    init 
};