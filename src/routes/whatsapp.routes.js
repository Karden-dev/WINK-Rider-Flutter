// src/routes/whatsapp.routes.js

const express = require('express');
const router = express.Router();
const whatsappController = require('../controllers/whatsapp.controller');

// Point d'entrée pour le Webhook Wasender.
// URL: /api/whatsapp/webhook
router.post('/webhook', whatsappController.handleWebhook);

module.exports = router;