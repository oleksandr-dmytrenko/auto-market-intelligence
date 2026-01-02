const tg = window.Telegram?.WebApp || { ready: () => {}, expand: () => {}, showAlert: (msg) => alert(msg), sendData: () => {}, close: () => {}, initDataUnsafe: {} };

try {
    tg.ready();
    tg.expand();
} catch (e) {
    console.warn('Telegram WebApp not available:', e);
}

function getApiBaseUrl() {
    const hostname = window.location.hostname;
    if (hostname === 'localhost' || hostname === '127.0.0.1') {
        return 'http://localhost:3000';
    }
    return window.location.origin.replace(/\/mini-app.*$/, '');
}

// Configuration
const API_BASE_URL = getApiBaseUrl();
let currentScreen = 'search';
let currentFilters = {};
let searchResults = [];
let currentVehicle = null;
let paymentType = null;
let alerts = [];
let currentAlert = null;

console.log('Mini App initialized');
console.log('API_BASE_URL:', API_BASE_URL);
console.log('Current URL:', window.location.href);
console.log('Telegram WebApp available:', !!window.Telegram?.WebApp);

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    console.log('DOM loaded, initializing app...');
    console.log('Available screens:', document.querySelectorAll('.screen').length);
    console.log('Loading screen:', document.getElementById('loading') ? 'found' : 'not found');
    console.log('Search screen:', document.getElementById('search-screen') ? 'found' : 'not found');
    
    const loadingScreen = document.getElementById('loading');
    if (loadingScreen) {
        loadingScreen.classList.add('active');
    }
    
    initializeApp();
});

function initializeApp() {
    const urlParams = new URLSearchParams(window.location.search);
    const type = urlParams.get('type');
    const userId = urlParams.get('user_id');
    const paymentId = urlParams.get('payment_id');
    
    // Handle payment result callback
    if (paymentId) {
        checkPaymentStatus(paymentId);
        return;
    }
    
    if (type === 'premium' || type === 'single_search') {
        paymentType = type;
        showPaymentScreen(type);
        return;
    }

    // Handle alerts type - open create alert form directly
    if (type === 'alerts') {
        setTimeout(() => {
            hideLoading();
            // Load brands first, then show form
            loadBrandsForAlert().then(() => {
                showCreateAlertScreen();
            }).catch((error) => {
                console.error('Error loading brands:', error);
                showCreateAlertScreen();
            });
        }, 100);
        return;
    }

    setTimeout(() => {
        hideLoading();
        showSearchScreen();
    }, 100);
    
    loadBrands()
        .then(() => {
            console.log('Brands loaded successfully');
        })
        .catch((error) => {
            console.error('Error loading brands:', error);
            tg.showAlert('Ошибка загрузки марок. Попробуйте позже.');
        });

    setupFormHandlers();
}

async function checkPaymentStatus(paymentId) {
    try {
        const response = await fetch(`${API_BASE_URL}/api/payments/${paymentId}/result`);
        const data = await response.json();
        
        if (data.status === 'success') {
            tg.showAlert(data.message || 'Оплата успешно завершена!');
            // Close mini app or redirect to main screen
            setTimeout(() => {
                tg.close();
            }, 2000);
        } else {
            tg.showAlert('Оплата не завершена. Попробуйте еще раз.');
            setTimeout(() => {
                hideLoading();
                showSearchScreen();
            }, 2000);
        }
    } catch (error) {
        console.error('Error checking payment status:', error);
        tg.showAlert('Ошибка проверки статуса оплаты');
        setTimeout(() => {
            hideLoading();
            showSearchScreen();
        }, 2000);
    }
}

function setupFormHandlers() {
    const makeSelect = document.getElementById('make');
    const modelSelect = document.getElementById('model');
    const searchForm = document.getElementById('search-form');

    makeSelect.addEventListener('change', async (e) => {
        const make = e.target.value;
        if (make) {
            modelSelect.disabled = false;
            await loadModels(make);
        } else {
            modelSelect.disabled = true;
            modelSelect.innerHTML = '<option value="">Сначала выберите марку</option>';
        }
    });

    searchForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        await performSearch();
    });

    // Alert form handlers
    const alertMakeSelect = document.getElementById('alert-make');
    const alertModelSelect = document.getElementById('alert-model');
    const alertForm = document.getElementById('alert-form');

    if (alertMakeSelect) {
        alertMakeSelect.addEventListener('change', async (e) => {
            const make = e.target.value;
            if (make) {
                alertModelSelect.disabled = false;
                await loadModelsForAlert(make);
            } else {
                alertModelSelect.disabled = true;
                alertModelSelect.innerHTML = '<option value="">Сначала выберите марку</option>';
            }
        });
    }

    if (alertForm) {
        alertForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            await saveAlert();
        });
    }
}

async function loadBrands() {
    try {
        console.log('Loading brands from:', `${API_BASE_URL}/api/brands`);
        const response = await fetch(`${API_BASE_URL}/api/brands`);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        const data = await response.json();
        console.log('Brands loaded:', data.brands?.length || 0);
        const makeSelect = document.getElementById('make');
        
        if (!makeSelect) {
            console.error('makeSelect element not found!');
            throw new Error('Form element not found');
        }
        
        makeSelect.innerHTML = '<option value="">Выберите марку</option>';
        if (data.brands && Array.isArray(data.brands)) {
            data.brands.forEach(brand => {
                const option = document.createElement('option');
                option.value = brand;
                option.textContent = brand;
                makeSelect.appendChild(option);
            });
        }
    } catch (error) {
        console.error('Error loading brands:', error);
        throw error;
    }
}

async function loadModels(make) {
    try {
        const response = await fetch(`${API_BASE_URL}/api/models?brand=${encodeURIComponent(make)}`);
        const data = await response.json();
        const modelSelect = document.getElementById('model');
        
        modelSelect.innerHTML = '<option value="">Выберите модель</option>';
        data.models.forEach(model => {
            const option = document.createElement('option');
            option.value = model;
            option.textContent = model;
            modelSelect.appendChild(option);
        });
    } catch (error) {
        console.error('Error loading models:', error);
        tg.showAlert('Ошибка загрузки моделей. Попробуйте позже.');
    }
}

async function performSearch() {
    const searchBtn = document.getElementById('search-btn');
    searchBtn.disabled = true;
    searchBtn.textContent = 'Поиск...';

    try {
        currentFilters = {
            make: document.getElementById('make').value,
            model: document.getElementById('model').value,
            year_from: document.getElementById('year_from').value || null,
            year_to: document.getElementById('year_to').value || null,
            mileage_from: document.getElementById('mileage_from').value || null,
            mileage_to: document.getElementById('mileage_to').value || null
        };

        if (!currentFilters.make || !currentFilters.model) {
            tg.showAlert('Пожалуйста, выберите марку и модель');
            searchBtn.disabled = false;
            searchBtn.textContent = '🔍 Найти автомобили';
            return;
        }

        const user = tg.initDataUnsafe?.user;
        const userId = user?.id || tg.initDataUnsafe?.user_id;
        const chatId = tg.initDataUnsafe?.chat?.id || userId;

        const response = await fetch(`${API_BASE_URL}/api/queries`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                telegram_id: userId,
                telegram_chat_id: chatId,
                search_active_auctions: true,
                ...currentFilters
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();

        tg.sendData(JSON.stringify({
            type: 'search_complete',
            filters: currentFilters,
            vehicles: []
        }));

        tg.showAlert('Поиск запущен! Мы пришлем результаты, как только найдем варианты.');
        
        searchBtn.disabled = false;
        searchBtn.textContent = '✅ Поиск отправлен';

    } catch (error) {
        console.error('Search error:', error);
        tg.showAlert('Ошибка при выполнении поиска. Попробуйте позже.');
        searchBtn.disabled = false;
        searchBtn.textContent = '🔍 Найти автомобили';
    }
}

function displayResults(vehicles) {
    searchResults = vehicles;
    const resultsList = document.getElementById('results-list');
    const noResults = document.getElementById('no-results');

    if (!vehicles || vehicles.length === 0) {
        resultsList.style.display = 'none';
        noResults.style.display = 'block';
        return;
    }

    resultsList.style.display = 'block';
    noResults.style.display = 'none';
    resultsList.innerHTML = '';

    vehicles.forEach((vehicle, index) => {
        const card = createVehicleCard(vehicle, index);
        resultsList.appendChild(card);
    });
}

function createVehicleCard(vehicle, index) {
    const card = document.createElement('div');
    card.className = 'vehicle-card';
    card.onclick = () => showVehicleDetails(vehicle);

    const imageUrl = vehicle.image_urls && vehicle.image_urls.length > 0 
        ? vehicle.image_urls[0] 
        : null;

    const price = vehicle.price || vehicle.final_price || 'N/A';
    const mileage = vehicle.mileage ? formatNumber(vehicle.mileage) + ' миль' : 'N/A';
    const location = vehicle.location || 'N/A';
    const damage = vehicle.damage_type || 'N/A';

    card.innerHTML = `
        ${imageUrl ? `<img src="${imageUrl}" alt="${vehicle.make} ${vehicle.model}" class="vehicle-image" onerror="this.style.display='none'">` : ''}
        <div class="vehicle-card-header">
            <div class="vehicle-title">${vehicle.make} ${vehicle.model} ${vehicle.year || ''}</div>
            <div class="vehicle-price">$${formatNumber(price)}</div>
        </div>
        <div class="vehicle-info">
            <div class="vehicle-info-item">
                <span class="vehicle-info-label">Пробег</span>
                <span class="vehicle-info-value">${mileage}</span>
            </div>
            <div class="vehicle-info-item">
                <span class="vehicle-info-label">Локация</span>
                <span class="vehicle-info-value">${location}</span>
            </div>
            <div class="vehicle-info-item">
                <span class="vehicle-info-label">Повреждения</span>
                <span class="vehicle-info-value">${damage}</span>
            </div>
            <div class="vehicle-info-item">
                <span class="vehicle-info-label">Статус</span>
                <span class="vehicle-info-value">${vehicle.auction_status || 'N/A'}</span>
            </div>
        </div>
        <div class="vehicle-actions">
            <button class="btn btn-primary btn-small" onclick="event.stopPropagation(); showVehicleDetailsFromIndex(${index})">
                Детали
            </button>
            ${vehicle.auction_url ? `<a href="${vehicle.auction_url}" target="_blank" class="btn btn-secondary btn-small" onclick="event.stopPropagation()">Аукцион</a>` : ''}
        </div>
    `;

    return card;
}

function showVehicleDetailsFromIndex(index) {
    showVehicleDetails(searchResults[index]);
}

function showVehicleDetails(vehicle) {
    if (!vehicle) {
        tg.showAlert('Информация о лоте не найдена');
        return;
    }
    
    currentVehicle = vehicle;
    const detailsDiv = document.getElementById('vehicle-details');

    const imageUrl = vehicle.image_urls && vehicle.image_urls.length > 0 
        ? vehicle.image_urls[0] 
        : null;

    detailsDiv.innerHTML = `
        ${imageUrl ? `<img src="${imageUrl}" alt="${vehicle.make} ${vehicle.model}" class="vehicle-details-image" onerror="this.style.display='none'">` : ''}
        <div class="vehicle-details-info">
            <div class="vehicle-details-section">
                <h3>Основная информация</h3>
                <div class="vehicle-details-item">
                    <span class="vehicle-details-label">Марка</span>
                    <span class="vehicle-details-value">${vehicle.make || 'N/A'}</span>
                </div>
                <div class="vehicle-details-item">
                    <span class="vehicle-details-label">Модель</span>
                    <span class="vehicle-details-value">${vehicle.model || 'N/A'}</span>
                </div>
                <div class="vehicle-details-item">
                    <span class="vehicle-details-label">Год</span>
                    <span class="vehicle-details-value">${vehicle.year || 'N/A'}</span>
                </div>
                <div class="vehicle-details-item">
                    <span class="vehicle-details-label">Пробег</span>
                    <span class="vehicle-details-value">${vehicle.mileage ? formatNumber(vehicle.mileage) + ' миль' : 'N/A'}</span>
                </div>
            </div>
            <div class="vehicle-details-section">
                <h3>Детали</h3>
                <div class="vehicle-details-item">
                    <span class="vehicle-details-label">Цвет</span>
                    <span class="vehicle-details-value">${vehicle.color || 'N/A'}</span>
                </div>
                <div class="vehicle-details-item">
                    <span class="vehicle-details-label">Повреждения</span>
                    <span class="vehicle-details-value">${vehicle.damage_type || 'N/A'}</span>
                </div>
                <div class="vehicle-details-item">
                    <span class="vehicle-details-label">Локация</span>
                    <span class="vehicle-details-value">${vehicle.location || 'N/A'}</span>
                </div>
                <div class="vehicle-details-item">
                    <span class="vehicle-details-label">Статус</span>
                    <span class="vehicle-details-value">${vehicle.auction_status || 'N/A'}</span>
                </div>
            </div>
            <div class="vehicle-details-section">
                <h3>Цена</h3>
                <div class="vehicle-details-item">
                    <span class="vehicle-details-label">Текущая цена</span>
                    <span class="vehicle-details-value">$${formatNumber(vehicle.price || vehicle.final_price || 0)}</span>
                </div>
            </div>
        </div>
        <div class="vehicle-actions" style="margin-top: 20px;">
            <button class="btn btn-primary" onclick="createAlertFromVehicle()">
                🔔 Создать уведомление
            </button>
            <button class="btn btn-secondary" onclick="initiatePaymentFromVehicle()">
                💰 Оплатить поиск
            </button>
            ${vehicle.auction_url ? `<a href="${vehicle.auction_url}" target="_blank" class="btn btn-secondary">🔗 Открыть аукцион</a>` : ''}
        </div>
    `;

    showScreen('vehicle');
}

function showPaymentScreen(type) {
    paymentType = type;
    const contentDiv = document.getElementById('payment-content');

    if (type === 'premium') {
        contentDiv.innerHTML = `
            <div class="payment-plan">
                <h3>💎 Премиум подписка</h3>
                <div class="payment-plan-price">$29.99/месяц</div>
                <ul class="payment-plan-features">
                    <li>Неограниченные поиски</li>
                    <li>Приоритетная поддержка</li>
                    <li>Расширенные фильтры</li>
                    <li>Уведомления о новых лотах</li>
                </ul>
                <button class="btn btn-primary" onclick="processPayment('premium', 29.99)">
                    Оплатить
                </button>
            </div>
        `;
    } else if (type === 'single_search') {
        contentDiv.innerHTML = `
            <div class="payment-plan">
                <h3>🔍 Разовый поиск</h3>
                <div class="payment-plan-price">$4.99</div>
                <ul class="payment-plan-features">
                    <li>Один поиск по параметрам</li>
                    <li>До 50 результатов</li>
                    <li>Детальная информация о лотах</li>
                </ul>
                <button class="btn btn-primary" onclick="processPayment('single_search', 4.99)">
                    Оплатить
                </button>
            </div>
        `;
    }

    showScreen('payment');
}

async function processPayment(type, amount) {
    const user = tg.initDataUnsafe?.user;
    const userId = user?.id || tg.initDataUnsafe?.user_id;

    if (!userId) {
        tg.showAlert('Ошибка: не удалось определить пользователя');
        return;
    }

    try {
        // Show loading
        const button = event?.target || document.querySelector('.btn-primary');
        if (button) {
            button.disabled = true;
            button.textContent = 'Обработка...';
        }

        // Create payment via API
        const response = await fetch(`${API_BASE_URL}/api/payments`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Telegram-User-Id': userId.toString()
            },
            body: JSON.stringify({
                payment_type: type,
                amount: amount,
                currency: 'USD',
                telegram_id: userId,
                username: user?.username
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Ошибка создания платежа');
        }

        const paymentData = await response.json();

        // Redirect to LiqPay checkout
        if (paymentData.checkout_url) {
            window.location.href = paymentData.checkout_url;
        } else {
            throw new Error('URL оплаты не получен');
        }
    } catch (error) {
        console.error('Payment error:', error);
        tg.showAlert(`Ошибка: ${error.message}`);
        
        // Re-enable button
        const button = event?.target || document.querySelector('.btn-primary');
        if (button) {
            button.disabled = false;
            button.textContent = 'Оплатить';
        }
    }
}

function initiatePaymentFromVehicle() {
    if (currentVehicle) {
        showPaymentScreen('single_search');
    }
}

function createAlertFromVehicle() {
    if (!currentVehicle) {
        tg.showAlert('Информация о машине не найдена');
        return;
    }

    // Pre-fill alert form with vehicle data
    currentAlert = null;
    const title = document.getElementById('alert-form-title');
    if (title) title.textContent = 'Создать уведомление';

    const form = document.getElementById('alert-form');
    if (form) form.reset();

    // Set default expiration date (1 month from now)
    const expiresAtInput = document.getElementById('alert-expires-at');
    if (expiresAtInput) {
        const date = new Date();
        date.setMonth(date.getMonth() + 1);
        expiresAtInput.value = date.toISOString().split('T')[0];
    }

    // Load brands and pre-fill form
    loadBrandsForAlert().then(() => {
        const makeSelect = document.getElementById('alert-make');
        const modelSelect = document.getElementById('alert-model');
        
        if (makeSelect && currentVehicle.make) {
            makeSelect.value = currentVehicle.make;
            if (currentVehicle.make) {
                loadModelsForAlert(currentVehicle.make).then(() => {
                    if (modelSelect && currentVehicle.model) {
                        modelSelect.value = currentVehicle.model;
                    }
                });
            }
        }

        if (document.getElementById('alert-year-from') && currentVehicle.year) {
            // Set year range around current vehicle year (±2 years)
            const year = currentVehicle.year;
            document.getElementById('alert-year-from').value = Math.max(1900, year - 2);
            document.getElementById('alert-year-to').value = Math.min(new Date().getFullYear() + 1, year + 2);
        }
        if (document.getElementById('alert-damage-type') && currentVehicle.damage_type) {
            document.getElementById('alert-damage-type').value = currentVehicle.damage_type;
        }
        if (document.getElementById('alert-mileage-min') && currentVehicle.mileage) {
            // Set mileage range around current vehicle mileage (±20%)
            const mileage = currentVehicle.mileage;
            const min = Math.max(0, Math.floor(mileage * 0.8));
            const max = Math.floor(mileage * 1.2);
            document.getElementById('alert-mileage-min').value = min;
            document.getElementById('alert-mileage-max').value = max;
        }

        showScreen('alert-form');
    });
}

function showScreen(screenName) {
    console.log('Showing screen:', screenName);
    const screens = document.querySelectorAll('.screen');
    console.log('Found screens:', screens.length);
    
    screens.forEach(screen => {
        screen.classList.remove('active');
    });
    
    const screenMap = {
        'search': 'search-screen',
        'results': 'results-screen',
        'vehicle': 'vehicle-screen',
        'payment': 'payment-screen',
        'alerts': 'alerts-screen',
        'alert-form': 'alert-form-screen'
    };

    const screenElement = document.getElementById(screenMap[screenName]);
    if (screenElement) {
        screenElement.classList.add('active');
        currentScreen = screenName;
        console.log('Screen activated:', screenName);
    } else {
        console.error('Screen element not found:', screenMap[screenName]);
    }
}

function showSearchScreen() {
    console.log('Showing search screen');
    showScreen('search');
    const searchScreen = document.getElementById('search-screen');
    if (searchScreen) {
        console.log('Search screen element found and activated');
    } else {
        console.error('Search screen element not found!');
    }
}

function showResultsScreen() {
    showScreen('results');
}

function goBackFromPayment() {
    if (currentVehicle) {
        showVehicleDetails(currentVehicle);
    } else {
        showSearchScreen();
    }
}

function hideLoading() {
    const loadingEl = document.getElementById('loading');
    if (loadingEl) {
        loadingEl.classList.remove('active');
        console.log('Loading screen hidden');
    } else {
        console.warn('Loading element not found');
    }
}

// Alerts functions
async function loadAlerts() {
    try {
        const user = tg.initDataUnsafe?.user;
        const userId = user?.id || tg.initDataUnsafe?.user_id;

        if (!userId) {
            // If no user ID, just show empty list
            alerts = [];
            displayAlerts();
            return;
        }

        const response = await fetch(`${API_BASE_URL}/api/vehicle_alerts`, {
            headers: {
                'X-Telegram-User-Id': userId.toString()
            }
        });

        if (!response.ok) {
            // If error, just show empty list instead of alert
            console.error('Error loading alerts:', response.status);
            alerts = [];
            displayAlerts();
            return;
        }

        const data = await response.json();
        alerts = data.alerts || [];
        displayAlerts();
    } catch (error) {
        console.error('Error loading alerts:', error);
        // Don't show error alert, just show empty list
        alerts = [];
        displayAlerts();
    }
}

function displayAlerts() {
    const alertsList = document.getElementById('alerts-list');
    const noAlerts = document.getElementById('no-alerts');

    if (!alerts || alerts.length === 0) {
        if (alertsList) alertsList.style.display = 'none';
        if (noAlerts) noAlerts.style.display = 'block';
        return;
    }

    if (alertsList) alertsList.style.display = 'block';
    if (noAlerts) noAlerts.style.display = 'none';
    if (alertsList) alertsList.innerHTML = '';

    alerts.forEach(alert => {
        const card = createAlertCard(alert);
        if (alertsList) alertsList.appendChild(card);
    });
}

function createAlertCard(alert) {
    const card = document.createElement('div');
    card.className = 'vehicle-card';
    
    const expiresAt = alert.expires_at ? new Date(alert.expires_at).toLocaleDateString('ru-RU') : 'N/A';
    const status = alert.active ? '✅ Активно' : '❌ Неактивно';
    let yearText = '';
    if (alert.year_from || alert.year_to) {
        if (alert.year_from && alert.year_to) {
            yearText = ` ${alert.year_from}-${alert.year_to}`;
        } else if (alert.year_from) {
            yearText = ` от ${alert.year_from}`;
        } else if (alert.year_to) {
            yearText = ` до ${alert.year_to}`;
        }
    }
    const mileageText = alert.mileage_min || alert.mileage_max 
        ? `Пробег: ${alert.mileage_min || 0} - ${alert.mileage_max || '∞'} миль`
        : '';

    card.innerHTML = `
        <div class="vehicle-card-header">
            <div class="vehicle-title">${alert.make} ${alert.model}${yearText}</div>
            <div class="vehicle-price">${status}</div>
        </div>
        <div class="vehicle-info">
            ${alert.damage_type ? `
            <div class="vehicle-info-item">
                <span class="vehicle-info-label">Повреждения</span>
                <span class="vehicle-info-value">${alert.damage_type}</span>
            </div>
            ` : ''}
            ${mileageText ? `
            <div class="vehicle-info-item">
                <span class="vehicle-info-label">Пробег</span>
                <span class="vehicle-info-value">${mileageText}</span>
            </div>
            ` : ''}
            <div class="vehicle-info-item">
                <span class="vehicle-info-label">Действует до</span>
                <span class="vehicle-info-value">${expiresAt}</span>
            </div>
        </div>
        <div class="vehicle-actions">
            <button class="btn btn-primary btn-small" onclick="editAlert('${alert.id}')">
                ✏️ Редактировать
            </button>
            <button class="btn btn-secondary btn-small" onclick="deleteAlert('${alert.id}')">
                🗑️ Удалить
            </button>
        </div>
    `;

    return card;
}

function showAlertsScreen() {
    showScreen('alerts');
    loadAlerts();
}

function showCreateAlertScreen() {
    currentAlert = null;
    const title = document.getElementById('alert-form-title');
    if (title) title.textContent = 'Создать уведомление';
    
    const form = document.getElementById('alert-form');
    if (form) form.reset();

    // Show screen first
    showScreen('alert-form');
    
    // Wait a bit for DOM to be ready, then load brands
    setTimeout(() => {
        const makeSelect = document.getElementById('alert-make');
        if (makeSelect) {
            // Always reload brands to ensure they're fresh
            loadBrandsForAlert().catch((error) => {
                console.error('Error loading brands:', error);
                tg.showAlert('Ошибка загрузки марок. Попробуйте позже.');
            });
        } else {
            console.error('alert-make element not found when showing create screen');
            // Retry after delay
            setTimeout(() => {
                loadBrandsForAlert().catch((error) => {
                    console.error('Error loading brands on retry:', error);
                });
            }, 300);
        }
    }, 150);
}

function editAlert(alertId) {
    currentAlert = alerts.find(a => a.id === alertId);
    if (!currentAlert) {
        tg.showAlert('Уведомление не найдено');
        return;
    }

    const title = document.getElementById('alert-form-title');
    if (title) title.textContent = 'Редактировать уведомление';

    // Populate form
    const makeSelect = document.getElementById('alert-make');
    const modelSelect = document.getElementById('alert-model');
    
    loadBrandsForAlert().then(() => {
        if (makeSelect) {
            makeSelect.value = currentAlert.make;
            if (currentAlert.make) {
                loadModelsForAlert(currentAlert.make).then(() => {
                    if (modelSelect && currentAlert.model) {
                        modelSelect.value = currentAlert.model;
                    }
                });
            }
        }

        if (document.getElementById('alert-year-from')) {
            document.getElementById('alert-year-from').value = currentAlert.year_from || '';
        }
        if (document.getElementById('alert-year-to')) {
            document.getElementById('alert-year-to').value = currentAlert.year_to || '';
        }
        if (document.getElementById('alert-damage-type')) {
            document.getElementById('alert-damage-type').value = currentAlert.damage_type || '';
        }
        if (document.getElementById('alert-mileage-min')) {
            document.getElementById('alert-mileage-min').value = currentAlert.mileage_min || '';
        }
        if (document.getElementById('alert-mileage-max')) {
            document.getElementById('alert-mileage-max').value = currentAlert.mileage_max || '';
        }

        showScreen('alert-form');
    });
}

async function loadBrandsForAlert() {
    try {
        console.log('Loading brands for alert form from:', `${API_BASE_URL}/api/brands`);
        const response = await fetch(`${API_BASE_URL}/api/brands`);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        const data = await response.json();
        console.log('Brands loaded for alert:', data.brands?.length || 0);
        
        // Wait a bit to ensure DOM is ready
        await new Promise(resolve => setTimeout(resolve, 100));
        
        const makeSelect = document.getElementById('alert-make');
        
        if (!makeSelect) {
            console.error('alert-make element not found!');
            // Retry after a short delay
            await new Promise(resolve => setTimeout(resolve, 200));
            const retrySelect = document.getElementById('alert-make');
            if (!retrySelect) {
                throw new Error('Form element not found after retry');
            }
            return loadBrandsForAlert(); // Retry once
        }
        
        makeSelect.innerHTML = '<option value="">Выберите марку</option>';
        if (data.brands && Array.isArray(data.brands) && data.brands.length > 0) {
            data.brands.forEach(brand => {
                const option = document.createElement('option');
                option.value = brand;
                option.textContent = brand;
                makeSelect.appendChild(option);
            });
            console.log('Brands populated in alert form:', data.brands.length);
        } else {
            console.warn('No brands in database. The list will be empty until vehicles are added.');
            makeSelect.innerHTML = '<option value="">Нет марок в базе данных</option>';
        }
    } catch (error) {
        console.error('Error loading brands for alert:', error);
        const makeSelect = document.getElementById('alert-make');
        if (makeSelect) {
            makeSelect.innerHTML = '<option value="">Ошибка загрузки марок</option>';
        }
        throw error;
    }
}

async function loadModelsForAlert(make) {
    try {
        const response = await fetch(`${API_BASE_URL}/api/models?brand=${encodeURIComponent(make)}`);
        const data = await response.json();
        const modelSelect = document.getElementById('alert-model');
        
        if (modelSelect) {
            modelSelect.innerHTML = '<option value="">Выберите модель</option>';
            if (data.models && Array.isArray(data.models)) {
                data.models.forEach(model => {
                    const option = document.createElement('option');
                    option.value = model;
                    option.textContent = model;
                    modelSelect.appendChild(option);
                });
            }
        }
    } catch (error) {
        console.error('Error loading models for alert:', error);
        tg.showAlert('Ошибка загрузки моделей');
    }
}

async function saveAlert() {
    const submitBtn = document.getElementById('alert-submit-btn');
    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = 'Сохранение...';
    }

    try {
        const user = tg.initDataUnsafe?.user;
        const userId = user?.id || tg.initDataUnsafe?.user_id;

        if (!userId) {
            throw new Error('Не удалось определить пользователя');
        }

        const alertData = {
            make: document.getElementById('alert-make').value,
            model: document.getElementById('alert-model').value,
            year_from: document.getElementById('alert-year-from').value || null,
            year_to: document.getElementById('alert-year-to').value || null,
            damage_type: document.getElementById('alert-damage-type').value || null,
            mileage_min: document.getElementById('alert-mileage-min').value || null,
            mileage_max: document.getElementById('alert-mileage-max').value || null,
            active: true // Always active when created
        };

        if (!alertData.make || !alertData.model) {
            throw new Error('Марка и модель обязательны');
        }

        const url = currentAlert 
            ? `${API_BASE_URL}/api/vehicle_alerts/${currentAlert.id}`
            : `${API_BASE_URL}/api/vehicle_alerts`;
        
        const method = currentAlert ? 'PUT' : 'POST';

        const response = await fetch(url, {
            method: method,
            headers: {
                'Content-Type': 'application/json',
                'X-Telegram-User-Id': userId.toString()
            },
            body: JSON.stringify({
                alert: alertData
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.errors?.join(', ') || 'Ошибка сохранения');
        }

        tg.showAlert(currentAlert ? 'Уведомление обновлено!' : 'Уведомление создано!');
        showAlertsScreen();
    } catch (error) {
        console.error('Error saving alert:', error);
        tg.showAlert(`Ошибка: ${error.message}`);
    } finally {
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Сохранить уведомление';
        }
    }
}

async function deleteAlert(alertId) {
    if (!confirm('Вы уверены, что хотите удалить это уведомление?')) {
        return;
    }

    try {
        const user = tg.initDataUnsafe?.user;
        const userId = user?.id || tg.initDataUnsafe?.user_id;

        if (!userId) {
            throw new Error('Не удалось определить пользователя');
        }

        const response = await fetch(`${API_BASE_URL}/api/vehicle_alerts/${alertId}`, {
            method: 'DELETE',
            headers: {
                'X-Telegram-User-Id': userId.toString()
            }
        });

        if (!response.ok) {
            throw new Error('Ошибка удаления');
        }

        tg.showAlert('Уведомление удалено');
        loadAlerts();
    } catch (error) {
        console.error('Error deleting alert:', error);
        tg.showAlert('Ошибка удаления уведомления');
    }
}

// Utility functions
function formatNumber(num) {
    if (!num) return '0';
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

if (tg.initData) {
    try {
        const data = JSON.parse(tg.initData);
        if (data.vehicles) {
            displayResults(data.vehicles);
            showResultsScreen();
        }
    } catch (e) {
        console.error('Error parsing init data:', e);
    }
}

