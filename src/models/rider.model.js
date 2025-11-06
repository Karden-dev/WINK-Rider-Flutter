// src/models/rider.model.js
const moment = require('moment');

let dbConnection;

module.exports = {
    init: (connection) => {
        dbConnection = connection;
    },

    findRiderOrders: async (filters) => {
        const connection = await dbConnection.getConnection();
        try {
            // Requête SQL de base SANS le WHERE principal pour le livreur au début
            let query = `
                SELECT
                    o.*,
                    s.name AS shop_name,
                    u.name AS deliveryman_name,
                    o.is_urgent,
                    o.picked_up_by_rider_at,
                    (
                        SELECT GROUP_CONCAT(CONCAT(oi.item_name, ' (x', oi.quantity, ')') SEPARATOR ', ')
                        FROM order_items oi WHERE oi.order_id = o.id
                    ) as items_list,
                    (
                        SELECT COUNT(om.id)
                        FROM order_messages om
                        WHERE om.order_id = o.id
                          AND om.user_id != ? -- Placeholder 1 (subquery unread)
                          AND NOT EXISTS (
                              SELECT 1 FROM message_read_status mrs
                              WHERE mrs.message_id = om.id AND mrs.user_id = ? -- Placeholder 2 (subquery unread)
                          )
                    ) as unread_count
                FROM orders o
                LEFT JOIN shops s ON o.shop_id = s.id
                LEFT JOIN users u ON o.deliveryman_id = u.id
            `;

            // Paramètres initiaux (pour la sous-requête unread_count)
            const params = [filters.deliverymanId, filters.deliverymanId];
            const whereConditions = []; // Tableau pour stocker les conditions WHERE

            // **CONDITION OBLIGATOIRE :** Filtrer par le livreur
            whereConditions.push('o.deliveryman_id = ?');
            params.push(filters.deliverymanId); // Placeholder 3

            // Filtre de statut (ne s'applique que si ce n'est pas 'all')
            if (filters.status && filters.status !== 'all') {
                if (Array.isArray(filters.status) && filters.status.length > 0) {
                    const statusPlaceholders = filters.status.map(() => '?').join(',');
                    whereConditions.push(`o.status IN (${statusPlaceholders})`);
                    params.push(...filters.status);
                } else if (!Array.isArray(filters.status)) {
                    whereConditions.push('o.status = ?');
                    params.push(filters.status);
                } else {
                    whereConditions.push('1=0'); // Tableau vide = ne rien retourner
                }
            }
            // Si filters.status est 'all' ou non défini, on n'ajoute PAS de condition de statut

            // Filtre de recherche
            if (filters.search) {
                whereConditions.push('(o.id LIKE ? OR o.customer_phone LIKE ? OR o.customer_name LIKE ?)');
                const searchTerm = `%${filters.search}%`;
                params.push(searchTerm, searchTerm, searchTerm);
            }

            // **FILTRE DE DATE CRUCIAL**
            if (filters.startDate && filters.endDate) {
                // Utiliser DATE() pour comparer uniquement la partie date
                whereConditions.push('DATE(o.created_at) BETWEEN ? AND ?');
                params.push(filters.startDate, filters.endDate);
            }

            // Construire la clause WHERE finale
            if (whereConditions.length > 0) {
                query += ' WHERE ' + whereConditions.join(' AND ');
            } else {
                 // S'il n'y a AUCUNE condition (ne devrait pas arriver car deliveryman_id est obligatoire),
                 // on ajoute une condition par sécurité pour éviter de tout retourner.
                 // Cependant, on a déjà ajouté deliveryman_id, donc ce else n'est pas strictement nécessaire.
                 // query += ' WHERE 1=0'; // Sécurité
            }


            query += ` GROUP BY o.id ORDER BY o.created_at DESC`;

            const [rows] = await connection.execute(query, params);
            return rows;
        } catch (error) {
            console.error("Erreur SQL dans RiderModel.findRiderOrders (v3):", error.message);
            console.error("Requête (v3):", query);
            console.error("Paramètres (v3):", params);
            throw error;
        } finally {
            connection.release();
        }
    },

    // --- Les autres fonctions (getOrdersCounts, findRiderNotifications) restent inchangées ---
    getOrdersCounts: async (riderId) => {
        const connection = await dbConnection.getConnection();
        try {
            const [rows] = await connection.execute(
                `SELECT status, COUNT(*) as count FROM orders WHERE deliveryman_id = ? GROUP BY status`,
                [riderId]
            );
            const counts = {
                'pending': 0, 'in_progress': 0, 'ready_for_pickup': 0, 'en_route': 0,
                'delivered': 0, 'cancelled': 0, 'failed_delivery': 0, 'reported': 0,
                'return_declared': 0, 'returned': 0
            };
            rows.forEach(row => {
                if (counts.hasOwnProperty(row.status)) {
                    counts[row.status] = row.count;
                }
            });
            return counts;
        } catch(error) {
            console.error("Erreur SQL dans RiderModel.getOrdersCounts:", error.message);
            throw error;
        } finally {
            connection.release();
        }
    },

    findRiderNotifications: async (riderId) => {
        const connection = await dbConnection.getConnection();
        try {
            const [rows] = await connection.execute(
                `SELECT
                    oh.id, oh.action, oh.created_at, oh.order_id, o.id as tracking_id
                FROM order_history oh JOIN orders o ON oh.order_id = o.id
                WHERE oh.user_id = ? AND oh.action = 'assigned'
                ORDER BY oh.created_at DESC LIMIT 10`,
                [riderId]
            );
            return rows;
        } catch(error) {
            console.error("Erreur SQL dans RiderModel.findRiderNotifications:", error.message);
            throw error;
        } finally {
            connection.release();
        }
    }
};