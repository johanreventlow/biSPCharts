// wizard-nav.js — Wizard navigation lock/unlock logic
(function() {
  // Tildel data-step attributter til navbar links efter DOM load.
  // bslib genererer nav-links dynamisk, saa vi kan ikke saette dem i R.
  // Tabs identificeres via deres data-value attribut (sat via nav_panel value param).
  function initWizardSteps() {
    var stepMap = { upload: "1", analyser: "2", eksporter: "3" };
    var navLinks = document.querySelectorAll('.navbar .nav-link[data-value]');
    navLinks.forEach(function(link) {
      var value = link.getAttribute('data-value');
      if (stepMap[value]) {
        link.setAttribute('data-step', stepMap[value]);
      }
    });
  }

  // Kald ved DOM ready og naar Shiny er connected
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initWizardSteps);
  } else {
    initWizardSteps();
  }
  $(document).on('shiny:connected', function() {
    // Re-init efter Shiny connection for at sikre attributter er sat
    setTimeout(initWizardSteps, 100);
  });

  // Lock et wizard-trin (forhindr klik)
  Shiny.addCustomMessageHandler('wizard-lock-step', function(step) {
    var links = document.querySelectorAll('[data-step="' + step + '"]');
    links.forEach(function(link) {
      link.classList.add('wizard-locked');
    });
  });

  // Unlock et wizard-trin (tillad klik)
  Shiny.addCustomMessageHandler('wizard-unlock-step', function(step) {
    var links = document.querySelectorAll('[data-step="' + step + '"]');
    links.forEach(function(link) {
      link.classList.remove('wizard-locked');
    });
  });

  // Intercept klik paa laaste tabs
  document.addEventListener('click', function(e) {
    var navLink = e.target.closest('.wizard-locked');
    if (navLink) {
      e.preventDefault();
      e.stopImmediatePropagation();
    }
  }, true);
})();
