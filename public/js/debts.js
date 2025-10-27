// js/debts.js

document.addEventListener('DOMContentLoaded', async () => {
    const API_BASE_URL = '/api';
   // Simulation de la récupération de l'utilisateur connecté
    const storedUser = localStorage.getItem('user') || sessionStorage.getItem('user');
    const user = storedUser ? JSON.parse(storedUser) : { id: 1, name: 'Admin Test', token: 'mock-token' };
    const CURRENT_USER_ID = user.id;
    // --- RÉFÉRENCES DOM ---
    const debtsTableBody = document.getElementById('debtsTableBody');
    const searchInput = document.getElementById('searchInput');
    const startDateFilter = document.getElementById('startDateFilter');
    const endDateFilter = document.getElementById('endDateFilter');
    const statusFilter = document.getElementById('statusFilter');
    const filterBtn = document.getElementById('filterBtn');
    
    // Cartes de statistiques
    const debtorsCount = document.getElementById('debtorsCount');
    const totalPendingDebts = document.getElementById('totalPendingDebts');
    const totalPaidDebts = document.getElementById('totalPaidDebts');
    const settlementRate = document.getElementById('settlementRate');

    // Modale d'ajout/modification
    const debtModal = new bootstrap.Modal(document.getElementById('addDebtModal'));
    const debtForm = document.getElementById('debtForm');
    const debtIdInput = document.getElementById('debtId');
    const shopSelect = document.getElementById('shopSelect');
    const amountInput = document.getElementById('amountInput');
    const typeSelect = document.getElementById('typeSelect');
    const dateInput = document.getElementById('dateInput');
    const commentInput = document.getElementById('commentInput');
    const debtSubmitBtn = document.getElementById('debtSubmitBtn');
    const addDebtModalLabel = document.getElementById('addDebtModalLabel');

    const sidebarToggler = document.getElementById('sidebar-toggler');
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    const logoutBtn = document.getElementById('logoutBtn');

    let shopsCache = [];
    let allDebts = [];

    const statusTranslations = { 'pending': 'En attente', 'paid': 'Réglé' };
    const typeTranslations = {
        'daily_balance': 'Bilan Négatif',
        'storage_fee': 'Frais de Stockage',
        'packaging': 'Frais d\'Emballage',
        'expedition': 'Frais d\'Expédition',
        'other': 'Autre'
    };
    const statusClasses = { 'pending': 'text-warning', 'paid': 'text-success' };

    // --- FONCTIONS UTILITAIRES ---
    
    /**
     * Affiche une notification toast stylisée.
     * @param {string} message - Le message à afficher.
     * @param {string} [type='success'] - Le type d'alerte (success, danger, warning, info).
     */
    const showNotification = (message, type = 'success') => {
        const container = document.getElementById('notification-container');
        const alert = document.createElement('div');
        alert.className = `alert alert-${type} alert-dismissible fade show`;
        alert.role = 'alert';
        alert.innerHTML = `${message}<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>`;
        container.appendChild(alert);
        
        // Fermeture automatique pour l'effet "toast"
        setTimeout(() => {
            const bsAlert = bootstrap.Alert.getOrCreateInstance(alert);
            bsAlert.close();
        }, 4000); 
    };

    /**
     * Formate un montant en FCFA avec séparateur de milliers.
     * @param {number|string} amount - Le montant à formater.
     * @returns {string} Le montant formaté.
     */
    const formatAmount = (amount) => `${parseFloat(amount || 0).toLocaleString('fr-FR')} FCFA`;

    // --- FONCTIONS PRINCIPALES ---
    
    /**
     * Récupère les créances depuis l'API en appliquant les filtres.
     */
    const fetchData = async () => {
        try {
            const params = {
                search: searchInput.value,
                startDate: startDateFilter.value,
                endDate: endDateFilter.value,
                status: statusFilter.value
            };
            const response = await axios.get(`${API_BASE_URL}/debts`, { params });
            allDebts = response.data;
            renderDebtsTable(allDebts);
            updateStats(allDebts);
        } catch (error) {
            console.error("Erreur lors de la récupération des créances:", error);
            debtsTableBody.innerHTML = `<tr><td colspan="7" class="text-center text-danger p-4">Erreur lors du chargement des données.</td></tr>`;
            showNotification("Erreur lors du chargement des créances.", "danger");
        }
    };
    
    /**
     * Récupère et peuple la liste des marchands actifs pour la modale d'ajout.
     */
    const fetchShops = async () => {
        try {
            const response = await axios.get(`${API_BASE_URL}/shops?status=actif`);
            shopsCache = response.data;
            shopSelect.innerHTML = '<option value="">Sélectionner un marchand</option>';
            shopsCache.forEach(shop => {
                const option = document.createElement('option');
                option.value = shop.id;
                option.textContent = shop.name;
                shopSelect.appendChild(option);
            });
        } catch (error) {
            console.error("Erreur lors du chargement des marchands:", error);
            showNotification("Erreur lors du chargement de la liste des marchands.", "danger");
        }
    };

    /**
     * Met à jour les cartes de statistiques avec les données de créances.
     * @param {Array<Object>} debts - Liste des objets de créances.
     */
    const updateStats = (debts) => {
        let pendingSum = 0;
        let paidSum = 0;
        const pendingDebtors = new Set();

        debts.forEach(debt => {
            if (debt.status === 'pending') {
                pendingSum += parseFloat(debt.amount);
                pendingDebtors.add(debt.shop_id);
            } else if (debt.status === 'paid') {
                paidSum += parseFloat(debt.amount);
            }
        });

        const totalDebtAmount = pendingSum + paidSum;
        const rate = totalDebtAmount > 0 ? (paidSum / totalDebtAmount) * 100 : 0;

        debtorsCount.textContent = pendingDebtors.size;
        totalPendingDebts.textContent = formatAmount(pendingSum);
        totalPaidDebts.textContent = formatAmount(paidSum);
        settlementRate.textContent = `${rate.toFixed(1)}%`;
    };

    /**
     * Génère et affiche les lignes du tableau des créances.
     * @param {Array<Object>} debts - Liste des objets de créances.
     */
    const renderDebtsTable = (debts) => {
        debtsTableBody.innerHTML = '';
        if (debts.length === 0) {
            debtsTableBody.innerHTML = `<tr><td colspan="8" class="text-center p-3">Aucune créance à afficher pour les filtres sélectionnés.</td></tr>`;
            return;
        }

        debts.forEach(debt => {
            const row = document.createElement('tr');
            const statusClass = statusClasses[debt.status] || 'text-secondary';
            const isManual = debt.type !== 'daily_balance';
            const settledAtDisplay = debt.settled_at ? moment(debt.settled_at).format('DD/MM/YYYY') : 'N/A'; // NOUVEAU

            
            row.innerHTML = `
                <td>${moment(debt.created_at).format('DD/MM/YYYY')}</td>
                <td>${debt.shop_name}</td>
                <td class="text-danger fw-bold">${formatAmount(debt.amount)}</td>
                <td><span class="badge bg-secondary">${typeTranslations[debt.type] || debt.type}</span></td>
                <td>${debt.comment || 'N/A'}</td>
                <td><span class="${statusClass} fw-bold">${statusTranslations[debt.status]}</span></td>
                <td>${settledAtDisplay}</td>
                <td class="text-center">
                    <div class="dropdown">
                        <button class="btn btn-sm btn-secondary dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                            <i class="bi bi-gear"></i>
                        </button>
                        <ul class="dropdown-menu">
                            ${debt.status === 'pending' ? `<li><a class="dropdown-item settle-btn" href="#" data-id="${debt.id}"><i class="bi bi-check-circle"></i> Régler</a></li>` : ''}
                            <li><a class="dropdown-item edit-btn ${!isManual || debt.status !== 'pending' ? 'disabled' : ''}" href="#" data-id="${debt.id}"><i class="bi bi-pencil"></i> Modifier</a></li>
                            <li><a class="dropdown-item delete-btn text-danger ${!isManual || debt.status !== 'pending' ? 'disabled' : ''}" href="#" data-id="${debt.id}"><i class="bi bi-trash"></i> Supprimer</a></li>
                        </ul>
                    </div>
                </td>
            `;
            debtsTableBody.appendChild(row);
        });
    };

    /**
     * Gère la soumission du formulaire d'ajout/modification de créance.
     * @param {Event} e - L'événement de soumission du formulaire.
     */
    const handleDebtFormSubmit = async (e) => {
        e.preventDefault();
        const debtData = {
            shop_id: shopSelect.value,
            amount: amountInput.value,
            type: typeSelect.value,
            comment: commentInput.value,
            created_at: dateInput.value,
            created_by: CURRENT_USER_ID,
            updated_by: CURRENT_USER_ID
        };

        try {
            if (debtIdInput.value) {
                await axios.put(`${API_BASE_URL}/debts/${debtIdInput.value}`, debtData);
                showNotification("Créance modifiée avec succès !");
            } else {
                await axios.post(`${API_BASE_URL}/debts`, debtData);
                showNotification("Créance manuelle ajoutée avec succès !");
            }
            debtModal.hide();
            fetchData();
        } catch (error) {
            showNotification(error.response?.data?.message || "Erreur lors de l'enregistrement.", 'danger');
        }
    };

    /**
     * Gère les actions sur les lignes du tableau (Édition, Suppression, Règlement).
     * @param {Event} e - L'événement de clic.
     */
    const handleTableActions = async (e) => {
        const target = e.target.closest('a');
        if (!target || target.classList.contains('disabled')) return;
        
        e.preventDefault(); 

        const debtId = target.dataset.id;
        
        if (target.classList.contains('edit-btn')) {
            const debt = allDebts.find(d => d.id == debtId);
            if (debt) {
                debtIdInput.value = debt.id;
                shopSelect.value = debt.shop_id;
                amountInput.value = debt.amount;
                typeSelect.value = debt.type;
                commentInput.value = debt.comment;
                dateInput.value = moment(debt.created_at).format('YYYY-MM-DD');
                addDebtModalLabel.textContent = "Modifier la créance manuelle";
                debtSubmitBtn.textContent = "Sauvegarder";
                debtModal.show();
            }
        } else if (target.classList.contains('delete-btn')) {
            if (confirm("Êtes-vous sûr de vouloir supprimer cette créance manuelle ?")) {
                try {
                    await axios.delete(`${API_BASE_URL}/debts/${debtId}`);
                    showNotification("Créance supprimée.");
                    fetchData();
                } catch (error) {
                    showNotification("Erreur lors de la suppression.", "danger");
                }
            }
        } else if (target.classList.contains('settle-btn')) {
             if (confirm("Confirmer le règlement de cette créance ?")) {
                try {
                    await axios.put(`${API_BASE_URL}/debts/${debtId}/settle`, { userId: CURRENT_USER_ID });
                    showNotification("Créance réglée avec succès.");
                    fetchData();
                } catch (error) {
                    showNotification(error.response?.data?.message || "Erreur lors du règlement.", "danger");
                }
            }
        }
    };


    // --- INITIALISATION ---
    
    /**
     * Initialise tous les écouteurs d'événements et charge les données initiales.
     */
    const initializeApp = async () => {
        // Initialisation des dates par défaut (Aujourd'hui)
        const today = moment().format('YYYY-MM-DD');
        startDateFilter.value = today;
        endDateFilter.value = today;
        dateInput.value = today;
        
        // --- Écouteurs de la Sidebar et déconnexion ---
        sidebarToggler?.addEventListener('click', () => {
            if (window.innerWidth < 992) {
                // Logique mobile : basculer la classe 'show' (définie dans le CSS de debts.html)
                sidebar?.classList.toggle('show');
            } else {
                // Logique Desktop : basculer la classe 'collapsed'
                sidebar?.classList.toggle('collapsed');
                mainContent?.classList.toggle('expanded');
            }
        });
        logoutBtn?.addEventListener('click', () => { 
            localStorage.removeItem('user');
            sessionStorage.removeItem('user');
            window.location.href = 'index.html'; 
        });
        
        // --- Écouteurs de filtres et soumission de formulaire ---
        filterBtn.addEventListener('click', fetchData);
        searchInput.addEventListener('input', fetchData);
        startDateFilter.addEventListener('change', fetchData);
        endDateFilter.addEventListener('change', fetchData);
        statusFilter.addEventListener('change', fetchData);
        debtForm.addEventListener('submit', handleDebtFormSubmit);
        debtsTableBody.addEventListener('click', handleTableActions);

        // Réinitialisation de la modale à la fermeture
        document.getElementById('addDebtModal').addEventListener('hidden.bs.modal', () => {
            debtForm.reset();
            debtIdInput.value = '';
            dateInput.value = moment().format('YYYY-MM-DD');
            addDebtModalLabel.textContent = "Ajouter une créance manuelle";
            debtSubmitBtn.textContent = "Ajouter";
        });
        
        // Mise en évidence du lien actif
        const currentPath = window.location.pathname.split('/').pop();
        document.querySelectorAll('.nav-link').forEach(link => {
            // Désactiver tous les liens de la barre latérale pour la gestion manuelle
            link.classList.remove('active');
        });

        // Activer le parent 'Versements' et le sous-lien 'Créances'
        const activeDebtLink = document.querySelector(`.dropdown-item[href="${currentPath}"]`);
        if (activeDebtLink) {
            activeDebtLink.classList.add('active');
            const parentDropdownToggle = activeDebtLink.closest('.dropdown').querySelector('.dropdown-toggle');
            if (parentDropdownToggle) {
                parentDropdownToggle.classList.add('active');
            }
        }

        // Chargement initial
        await fetchShops();
        await fetchData();
    };

    initializeApp();
});