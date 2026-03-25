// local-storage.js
// Browser localStorage integration for SPC App

// Save data to localStorage with app prefix
window.saveAppState = function(key, data) {
  try {
    localStorage.setItem('spc_app_' + key, JSON.stringify(data));
    return true;
  } catch(e) {
    console.error('Failed to save to localStorage:', e);
    return false;
  }
};

// Load data from localStorage
window.loadAppState = function(key) {
  try {
    var data = localStorage.getItem('spc_app_' + key);
    if (data) {
      return JSON.parse(data);
    } else {
      return null;
    }
  } catch(e) {
    console.error('Failed to load from localStorage:', e);
    return null;
  }
};

// Clear specific key from localStorage
window.clearAppState = function(key) {
  try {
    localStorage.removeItem('spc_app_' + key);
    return true;
  } catch(e) {
    console.error('Failed to clear localStorage:', e);
    return false;
  }
};

// Check if data exists in localStorage
window.hasAppState = function(key) {
  return localStorage.getItem('spc_app_' + key) !== null;
};
