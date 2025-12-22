const fs = require('fs');
const path = require('path');

// Setup window and document before loading app.js
let mockLocation;
let mockTelegramWebApp;

function setupWindow(locationConfig = { hostname: 'localhost', origin: 'http://localhost:3000' }) {
  mockTelegramWebApp = {
    ready: jest.fn(),
    expand: jest.fn(),
    showAlert: jest.fn(),
    sendData: jest.fn(),
    close: jest.fn(),
    initDataUnsafe: {}
  };

  mockLocation = {
    hostname: locationConfig.hostname,
    origin: locationConfig.origin,
    href: locationConfig.href || `${locationConfig.origin}/mini-app`,
    replace: jest.fn()
  };

  // Override window.location using Object.defineProperty
  Object.defineProperty(window, 'location', {
    value: mockLocation,
    writable: true,
    configurable: true
  });

  // Ensure window.Telegram is available
  if (!window.Telegram) {
    window.Telegram = { WebApp: mockTelegramWebApp };
  } else {
    window.Telegram.WebApp = mockTelegramWebApp;
  }

  // Update location properties
  Object.defineProperty(window.location, 'hostname', {
    value: locationConfig.hostname,
    writable: true,
    configurable: true
  });

  Object.defineProperty(window.location, 'origin', {
    value: locationConfig.origin,
    writable: true,
    configurable: true
  });
}

// Initial setup - must happen before eval
setupWindow();

// Ensure window.Telegram.WebApp is properly set before eval
// This is critical - tg in app.js captures this reference
// Make sure it has all required methods
if (!window.Telegram) {
  window.Telegram = { WebApp: mockTelegramWebApp };
} else if (!window.Telegram.WebApp) {
  window.Telegram.WebApp = mockTelegramWebApp;
} else {
  // Update existing object to match mockTelegramWebApp - maintain reference
  Object.assign(window.Telegram.WebApp, mockTelegramWebApp);
  // Ensure all methods exist
  if (!window.Telegram.WebApp.showAlert) {
    window.Telegram.WebApp.showAlert = mockTelegramWebApp.showAlert;
  }
}

// Ensure document.addEventListener exists (jsdom provides this, but ensure it's available)
if (!document.addEventListener) {
  document.addEventListener = jest.fn();
}

// Ensure window.console exists
if (!window.console) {
  window.console = console;
}

// Load app.js after window is set up
const appJsContent = fs.readFileSync(path.join(__dirname, '../app.js'), 'utf8');
// Note: We ensure window.Telegram.WebApp exists before eval, so tg should capture it

// Execute code in IIFE to ensure proper scoping
try {
  const wrappedCode = `
    (function() {
      ${appJsContent}
      // Explicitly assign functions to window for access in tests
      if (typeof getApiBaseUrl === 'function') window.getApiBaseUrl = getApiBaseUrl;
      if (typeof loadBrands === 'function') window.loadBrands = loadBrands;
      if (typeof loadModels === 'function') window.loadModels = loadModels;
      if (typeof performSearch === 'function') window.performSearch = performSearch;
      if (typeof formatNumber === 'function') window.formatNumber = formatNumber;
      if (typeof showScreen === 'function') window.showScreen = showScreen;
      if (typeof displayResults === 'function') window.displayResults = displayResults;
    })();
  `;
  
  // Execute in window context - window.Telegram.WebApp should already be set
  eval(wrappedCode);
} catch (error) {
  console.error('Error evaluating app.js:', error);
  throw error;
}

// Extract functions from window to make them available in test scope
const getApiBaseUrl = window.getApiBaseUrl;
const loadBrands = window.loadBrands;
const loadModels = window.loadModels;
const performSearch = window.performSearch;
const formatNumber = window.formatNumber;
const showScreen = window.showScreen;
const displayResults = window.displayResults;

describe('Mini App', () => {
  let originalFetch;
  let fetchMock;

  beforeEach(() => {
    // Setup default location
    setupWindow({ hostname: 'localhost', origin: 'http://localhost:3000' });

    // Ensure window.Telegram is set - update existing object to maintain reference
    if (!window.Telegram) {
      window.Telegram = { WebApp: {} };
    }
    if (!window.Telegram.WebApp) {
      window.Telegram.WebApp = {};
    }
    
    // Update properties of existing object to maintain reference that tg has
    mockTelegramWebApp = window.Telegram.WebApp;
    mockTelegramWebApp.ready = jest.fn();
    mockTelegramWebApp.expand = jest.fn();
    mockTelegramWebApp.showAlert = jest.fn();
    mockTelegramWebApp.sendData = jest.fn();
    mockTelegramWebApp.close = jest.fn();
    mockTelegramWebApp.initDataUnsafe = {};

    originalFetch = global.fetch;
    fetchMock = jest.fn();
    global.fetch = fetchMock;

    document.body.innerHTML = `
      <div id="loading" class="screen"></div>
      <div id="search-screen" class="screen">
        <form id="search-form">
          <select id="make"></select>
          <select id="model"></select>
          <input id="year_from" />
          <input id="year_to" />
          <input id="mileage_from" />
          <input id="mileage_to" />
          <button id="search-btn">Search</button>
        </form>
      </div>
      <div id="results-screen" class="screen">
        <div id="results-list"></div>
        <div id="no-results" style="display: none;"></div>
      </div>
      <div id="vehicle-screen" class="screen">
        <div id="vehicle-details"></div>
      </div>
      <div id="payment-screen" class="screen">
        <div id="payment-content"></div>
      </div>
    `;
  });

  afterEach(() => {
    global.fetch = originalFetch;
    jest.clearAllMocks();
  });

  describe('getApiBaseUrl', () => {
    it('returns localhost URL for localhost', () => {
      setupWindow({ hostname: 'localhost', origin: 'http://localhost:3000' });
      const url = getApiBaseUrl();
      expect(url).toBe('http://localhost:3000');
    });

    it('returns origin URL for production', () => {
      setupWindow({ hostname: 'example.com', origin: 'https://example.com' });
      const url = getApiBaseUrl();
      expect(url).toBe('https://example.com');
    });
  });

  describe('loadBrands', () => {
    it('loads brands from API', async () => {
      fetchMock.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ brands: ['Toyota', 'Honda', 'BMW'] })
      });

      await loadBrands();

      expect(fetchMock).toHaveBeenCalledWith('http://localhost:3000/api/brands');
      const makeSelect = document.getElementById('make');
      expect(makeSelect.innerHTML).toContain('Toyota');
    });

    it('handles API errors', async () => {
      fetchMock.mockRejectedValueOnce(new Error('Network error'));

      await expect(loadBrands()).rejects.toThrow();
    });
  });

  describe('loadModels', () => {
    it('loads models for a brand', async () => {
      fetchMock.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ models: ['Camry', 'Corolla'] })
      });

      await loadModels('Toyota');

      expect(fetchMock).toHaveBeenCalledWith('http://localhost:3000/api/models?brand=Toyota');
      const modelSelect = document.getElementById('model');
      expect(modelSelect.innerHTML).toContain('Camry');
    });
  });

  describe('formatNumber', () => {
    it('formats numbers with commas', () => {
      expect(formatNumber(1000)).toBe('1,000');
      expect(formatNumber(1000000)).toBe('1,000,000');
    });

    it('handles zero', () => {
      expect(formatNumber(0)).toBe('0');
    });

    it('handles null', () => {
      expect(formatNumber(null)).toBe('0');
    });
  });

  describe('showScreen', () => {
    it('shows specified screen', () => {
      showScreen('search');
      const searchScreen = document.getElementById('search-screen');
      expect(searchScreen.classList.contains('active')).toBe(true);
    });

    it('hides other screens', () => {
      document.getElementById('results-screen').classList.add('active');
      showScreen('search');
      const resultsScreen = document.getElementById('results-screen');
      expect(resultsScreen.classList.contains('active')).toBe(false);
    });
  });

  describe('displayResults', () => {
    it('displays vehicle cards', () => {
      const vehicles = [
        { make: 'Toyota', model: 'Camry', year: 2020, price: 15000 }
      ];
      displayResults(vehicles);
      const resultsList = document.getElementById('results-list');
      expect(resultsList.innerHTML).toContain('Toyota');
    });

    it('shows no results message', () => {
      displayResults([]);
      const noResults = document.getElementById('no-results');
      expect(noResults.style.display).toBe('block');
    });
  });
});

