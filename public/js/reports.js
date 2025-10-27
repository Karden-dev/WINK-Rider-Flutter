// public/js/reports.js
/**
 * Module de gestion des rapports journaliers (Admin).
 */
document.addEventListener('DOMContentLoaded', async () => {
    const API_BASE_URL = '/api';
    
    // --- RÉFÉRENCES DOM ---
    const reportDateInput = document.getElementById('reportDate');
    const searchMerchantInput = document.getElementById('searchMerchantInput');
    const reportsTableBody = document.getElementById('reportsTableBody');
    const totalRemittanceAmount = document.getElementById('totalRemittanceAmount');
    const totalPackagingAmount = document.getElementById('totalPackagingAmount');
    const totalStorageAmount = document.getElementById('totalStorageAmount');
    const totalDebtAmount = document.getElementById('totalDebtAmount');
    const totalActiveMerchants = document.getElementById('totalActiveMerchants');
    const itemsPerPageSelect = document.getElementById('itemsPerPage');
    const paginationInfo = document.getElementById('paginationInfo');
    const currentPageDisplay = document.getElementById('currentPageDisplay');
    const firstPageBtn = document.getElementById('firstPage');
    const prevPageBtn = document.getElementById('prevPage');
    const nextPageBtn = document.getElementById('nextPage');
    const lastPageBtn = document.getElementById('lastPage');
    const sidebarToggler = document.getElementById('sidebar-toggler');
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    const logoutBtn = document.getElementById('logoutBtn');
    const processStorageBtn = document.getElementById('processStorageBtn');
    const recalculateBtn = document.getElementById('recalculateBtn');
    
    // Références DOM pour la modale de confirmation
    const recalculateConfirmModalEl = document.getElementById('recalculateConfirmModal');
    const recalculateConfirmModal = recalculateConfirmModalEl ? new bootstrap.Modal(recalculateConfirmModalEl) : null;
    const confirmRecalculateBtn = document.getElementById('confirmRecalculateBtn');
    
    // --- Caches de données et état ---
    let allReports = [];
    let filteredReports = [];
    let currentPage = 1;
    let itemsPerPage = 10;

    // --- Fonctions utilitaires ---
    
    /**
     * Affiche une notification toast.
     * @param {string} message - Message de la notification.
     * @param {string} [type='success'] - Type de notification.
     */
    const showNotification = (message, type = 'success') => {
        const container = document.getElementById('notification-container');
        if (!container) return;
        const alert = document.createElement('div');
        alert.className = `alert alert-${type} alert-dismissible fade show`;
        alert.role = 'alert';
        alert.innerHTML = `${message}<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>`;
        container.appendChild(alert);
        
        setTimeout(() => {
            const bsAlert = bootstrap.Alert.getOrCreateInstance(alert);
            if (bsAlert) bsAlert.close();
        }, 5000);
    };

    /**
     * Formate un montant en FCFA.
     * @param {number|string} amount - Le montant.
     * @returns {string} Le montant formaté.
     */
    const formatAmount = (amount) => `${parseFloat(amount || 0).toLocaleString('fr-FR')} FCFA`;
    
    /**
     * Affiche l'état de chargement dans le tableau.
     * @param {HTMLElement} element - Le corps du tableau.
     */
    const showLoading = (element) => {
        element.innerHTML = '<tr><td colspan="11" class="text-center p-4"><div class="spinner-border text-corail" role="status"><span class="visually-hidden">Chargement...</span></div></td></tr>';
    };

    /**
     * Obtient l'en-tête d'authentification.
     * @returns {Object|null} L'objet headers ou null.
     */
    const getAuthHeader = () => {
        if (typeof AuthManager === 'undefined' || !AuthManager.getToken) { return null; }
        const token = AuthManager.getToken();
        return token ? { 'Authorization': `Bearer ${token}` } : null;
    };
    
    /**
     * Copie un texte dans le presse-papiers.
     * @param {string} text - Le texte à copier.
     */
    const copyToClipboard = (text) => {
        if (!navigator.clipboard) {
            showNotification("Le presse-papiers n'est pas supporté (fallback nécessaire).", 'warning');
            return;
        }
        navigator.clipboard.writeText(text).then(() => {
            showNotification("Lien d'export PDF copié !", 'info');
        }).catch(err => {
            console.error('Erreur de copie:', err);
            showNotification("Échec de la copie.", 'danger');
        });
    };

    // --- FONCTIONS PRINCIPALES ---

    /**
     * Récupère les rapports détaillés à partir de la route /reports.
     * @param {string} date - La date du rapport.
     */
    const fetchReports = async (date) => {
        const headers = getAuthHeader();
        if (!date || !headers) {
            reportsTableBody.innerHTML = '<tr><td colspan="11" class="text-center">Veuillez sélectionner une date pour afficher les rapports.</td></tr>';
            updateGlobalTotals([]);
            return;
        }
        try {
            showLoading(reportsTableBody);
            
            // UTILISATION DE LA ROUTE FONCTIONNELLE: /api/reports
            const res = await axios.get(`${API_BASE_URL}/reports`, { params: { date }, headers });
            
            allReports = res.data; 
            applyFiltersAndRender();
        } catch (error) {
            console.error("Erreur lors du chargement des rapports:", error);
            reportsTableBody.innerHTML = '<tr><td colspan="11" class="text-center text-danger">Erreur lors du chargement des rapports.</td></tr>';
            showNotification(`Erreur: ${error.response?.data?.message || 'Serveur injoignable.'}`, 'danger');
            if (error.response?.status === 401 || error.response?.status === 403) AuthManager.logout();
        }
    };

    /**
     * Applique le filtre de recherche et met à jour les totaux et le tableau.
     */
    const applyFiltersAndRender = () => {
        const searchTerm = searchMerchantInput.value.toLowerCase();
        
        updateGlobalTotals(allReports); 
        
        filteredReports = allReports.filter(report => 
            report.total_orders_delivered > 0 &&
            report.shop_name.toLowerCase().includes(searchTerm)
        );
        
        filteredReports.sort((a, b) => a.shop_name.localeCompare(b.shop_name));

        currentPage = 1;
        renderReportsTable(filteredReports);
        updatePaginationInfo(filteredReports.length);
    };

    /**
     * Met à jour les cartes de totaux globaux.
     * @param {Array<Object>} reports - Liste des rapports.
     */
    const updateGlobalTotals = (reports) => {
        let totalRemit = 0, totalDebt = 0, totalPackaging = 0, totalStorage = 0, activeMerchantsCount = 0;

        reports.forEach(report => {
            if (report.total_orders_sent > 0) {
                activeMerchantsCount++; 
            }
            totalPackaging += parseFloat(report.total_packaging_fees || 0);
            totalStorage += parseFloat(report.total_storage_fees || 0);
            
            const amountToRemit = parseFloat(report.amount_to_remit || 0);
            if (amountToRemit > 0) {
                totalRemit += amountToRemit;
            } else if (amountToRemit < 0) {
                totalDebt += Math.abs(amountToRemit);
            }
        });
        
        // Mise à jour des éléments DOM des cartes
        document.getElementById('totalActiveMerchants').textContent = activeMerchantsCount;
        totalRemittanceAmount.textContent = formatAmount(totalRemit);
        totalDebtAmount.textContent = formatAmount(totalDebt);
        totalPackagingAmount.textContent = formatAmount(totalPackaging);
        totalStorageAmount.textContent = formatAmount(totalStorage);
    };

    /**
     * Rend le tableau des rapports détaillés.
     * @param {Array<Object>} reports - Liste des rapports filtrés à rendre.
     */
    const renderReportsTable = (reports) => {
        reportsTableBody.innerHTML = '';
        if (reports.length === 0) {
            reportsTableBody.innerHTML = '<tr><td colspan="11" class="text-center p-3">Aucun rapport détaillé trouvé.</td></tr>';
            updatePaginationInfo(0);
            return;
        }

        const startIndex = (currentPage - 1) * itemsPerPage;
        const reportsToRender = reports.slice(startIndex, startIndex + itemsPerPage);

        reportsToRender.forEach((report, index) => {
            const row = document.createElement('tr');
            const rank = startIndex + index + 1;
            const amountToRemitClass = (report.amount_to_remit || 0) < 0 ? 'text-danger fw-bold' : 'text-success fw-bold';
            
            // Assumer que report.id est l'ID nécessaire pour l'export
            const pdfUrl = `${API_BASE_URL}/reports/${report.id}/export-pdf?date=${reportDateInput.value}`;
            const storageKey = `copied-report-${reportDateInput.value}-${report.shop_id}`;
            const isCopied = sessionStorage.getItem(storageKey);
            const buttonClass = isCopied ? 'btn-success' : 'btn-info';
            const buttonIcon = isCopied ? 'bi-clipboard-check' : 'bi-clipboard';
            const buttonTitle = isCopied ? 'Rapport déjà copié' : 'Copier le lien PDF';

            row.innerHTML = `
                <td>${rank}.</td>
                <td>${report.shop_name}</td>
                <td>${report.total_orders_sent || 0}</td>
                <td>${report.total_orders_delivered || 0}</td>
                <td class="text-end">${formatAmount(report.total_revenue_articles || 0)}</td>
                <td class="text-end">${formatAmount(report.total_delivery_fees || 0)}</td>
                <td class="text-end">${formatAmount(report.total_expedition_fees || 0)}</td>
                <td class="text-end">${formatAmount(report.total_packaging_fees || 0)}</td>
                <td class="text-end">${formatAmount(report.total_storage_fees || 0)}</td>
                <td class="text-end ${amountToRemitClass}">${formatAmount(report.amount_to_remit)}</td>
                <td>
                    <div class="dropdown">
                        <button class="btn btn-sm btn-secondary dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false" title="Actions"><i class="bi bi-gear"></i></button>
                        <ul class="dropdown-menu dropdown-menu-end">
                            <li><a class="dropdown-item export-pdf-btn" href="${pdfUrl}" target="_blank"><i class="bi bi-file-earmark-pdf me-2"></i> Exporter PDF</a></li>
                            <li><a class="dropdown-item copy-clipboard-btn" href="#" data-pdf-url="${pdfUrl}" data-storage-key="${storageKey}"><i class="bi ${buttonIcon} me-2"></i> Copier Lien PDF</a></li>
                            <li><hr class="dropdown-divider"></li>
                            <li><a class="dropdown-item details-btn" href="#"><i class="bi bi-eye me-2"></i> Détails (Commandes)</a></li>
                        </ul>
                    </div>
                </td>`;
            reportsTableBody.appendChild(row);
        });

        // Attacher l'événement de copie après le rendu
        reportsTableBody.querySelectorAll('.copy-clipboard-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                const url = btn.dataset.pdfUrl;
                const storageKey = btn.dataset.storageKey;
                
                if (url) {
                    copyToClipboard(url);
                    sessionStorage.setItem(storageKey, 'true');
                    btn.querySelector('i').classList.replace('bi-clipboard', 'bi-clipboard-check');
                    btn.classList.replace('btn-info', 'btn-success');
                    btn.title = 'Rapport déjà copié';
                }
            });
        });

        updatePaginationInfo(filteredReports.length);
    };

    /**
     * Met à jour l'affichage de la pagination.
     * @param {number} totalItems - Nombre total d'éléments.
     */
    const updatePaginationInfo = (totalItems) => {
        const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
        if (currentPage > totalPages) currentPage = totalPages;

        if (currentPageDisplay) currentPageDisplay.textContent = currentPage;
        if (paginationInfo) paginationInfo.textContent = `Page ${currentPage} sur ${totalPages} (${totalItems} entrées)`;

        firstPageBtn?.classList.toggle('disabled', currentPage === 1 || totalPages === 0);
        prevPageBtn?.classList.toggle('disabled', currentPage === 1 || totalPages === 0);
        nextPageBtn?.classList.toggle('disabled', currentPage >= totalPages || totalPages === 0);
        lastPageBtn?.classList.toggle('disabled', currentPage >= totalPages || totalPages === 0);
    };

    /**
     * Gère le changement de page.
     * @param {number} newPage - Numéro de la nouvelle page.
     */
    const handlePageChange = (newPage) => {
        const totalPages = Math.ceil(filteredReports.length / itemsPerPage);
        if (newPage < 1 || newPage > totalPages) return;
        currentPage = newPage;
        renderReportsTable(filteredReports);
    };

    // --- GESTION DES ACTIONS SPÉCIFIQUES ---

    /**
     * Ouvre la modale de confirmation pour le recalcul.
     */
    const openRecalculateModal = () => {
        const date = reportDateInput.value;
        if (!date) return showNotification("Veuillez sélectionner une date.", 'warning');

        document.getElementById('recalculateDateDisplay').textContent = moment(date).format('DD/MM/YYYY');
        document.getElementById('confirmRecalculateDate').value = date;
        recalculateConfirmModal.show();
    };

    /**
     * Soumet la demande de recalcul des rapports.
     */
    const confirmRecalculate = async () => {
        const date = document.getElementById('confirmRecalculateDate').value;
        const headers = getAuthHeader();
        if (!date || !headers) return;
        
        confirmRecalculateBtn.disabled = true;
        confirmRecalculateBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Recalcul...';

        try {
            await axios.post(`${API_BASE_URL}/reports/recalculate`, { date }, { headers });
            showNotification(`Recalcul du rapport du ${moment(date).format('DD/MM/YYYY')} lancé.`, 'success');
            recalculateConfirmModal.hide();
            fetchReports(date);
        } catch (error) {
            showNotification(error.response?.data?.message || "Échec du recalcul.", 'danger');
            if (error.response?.status === 401 || error.response?.status === 403) AuthManager.logout();
        } finally {
            confirmRecalculateBtn.disabled = false;
            confirmRecalculateBtn.innerHTML = '<i class="bi bi-arrow-repeat me-2"></i> Confirmer le Recalcul';
        }
    };

    /**
     * Déclenche le traitement des frais de stockage.
     */
    const processStorageFees = async () => {
         const date = reportDateInput.value;
         const headers = getAuthHeader();
         if (!date || !headers) return showNotification("Veuillez sélectionner une date.", 'warning');

         if (!confirm(`Voulez-vous vraiment traiter les frais de stockage pour le ${moment(date).format('DD/MM/YYYY')} ?`)) return;

         processStorageBtn.disabled = true;
         processStorageBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Traitement...';

         try {
             await axios.post(`${API_BASE_URL}/reports/process-storage-fees`, { date }, { headers });
             showNotification("Traitement des frais de stockage terminé. Les créances ont été créées.", 'success');
             fetchReports(date);
         } catch (error) {
             showNotification(error.response?.data?.message || "Échec du traitement des frais de stockage.", 'danger');
             if (error.response?.status === 401 || error.response?.status === 403) AuthManager.logout();
         } finally {
             processStorageBtn.disabled = false;
             processStorageBtn.innerHTML = '<i class="bi bi-box-seam me-1"></i> Traiter le stockage';
         }
     };

    // --- INITIALISATION ---

    const initializeApp = () => {
        const today = moment().format('YYYY-MM-DD');
        if (reportDateInput) reportDateInput.value = today;
        itemsPerPage = parseInt(itemsPerPageSelect?.value || 25);
        
        // --- Événements globaux ---
        const debounce = (func, delay = 300) => { let timeout; return (...args) => { clearTimeout(timeout); timeout = setTimeout(() => func.apply(this, args), delay); }; };

        document.getElementById('sidebar-toggler')?.addEventListener('click', () => {
            const sidebar = document.getElementById('sidebar');
            const mainContent = document.getElementById('main-content');
            if (window.innerWidth < 992) sidebar?.classList.toggle('show');
            else { sidebar?.classList.toggle('collapsed'); mainContent?.classList.toggle('expanded'); }
        });
        document.getElementById('logoutBtn')?.addEventListener('click', (e) => { e.preventDefault(); AuthManager.logout(); });

        // --- Événements de contrôle ---
        reportDateInput?.addEventListener('change', () => fetchReports(reportDateInput.value));
        searchMerchantInput?.addEventListener('input', debounce(applyFiltersAndRender));

        // Boutons d'action
        recalculateBtn?.addEventListener('click', openRecalculateModal);
        confirmRecalculateBtn?.addEventListener('click', confirmRecalculate);
        processStorageBtn?.addEventListener('click', processStorageFees);
        exportPdfBtn?.addEventListener('click', (e) => {
             e.preventDefault();
             const date = reportDateInput.value;
             if (!date) return showNotification("Sélectionnez une date.", 'warning');
             const reportUrl = `${API_BASE_URL}/reports/summary/export-pdf?date=${date}`;
             window.open(reportUrl, '_blank');
        });
        
        // Pagination
        itemsPerPageSelect?.addEventListener('change', (e) => { itemsPerPage = parseInt(e.target.value); currentPage = 1; renderPaginatedTable(); });
        firstPageBtn?.addEventListener('click', (e) => { e.preventDefault(); handlePageChange(1); });
        prevPageBtn?.addEventListener('click', (e) => { e.preventDefault(); handlePageChange(currentPage - 1); });
        nextPageBtn?.addEventListener('click', (e) => { e.preventDefault(); handlePageChange(currentPage + 1); });
        lastPageBtn?.addEventListener('click', (e) => { e.preventDefault(); handlePageChange(Math.ceil(filteredReports.length / itemsPerPage)); });

        // Premier chargement
        fetchReports(today);
    };

    // Démarrage de l'application
    if (typeof AuthManager !== 'undefined') {
        AuthManager.init();
        if (AuthManager.getUser()) {
            initializeApp();
        } else {
            document.addEventListener('authManagerReady', initializeApp);
        }
    }
});