// wizard-nav.js — Wizard navigation lock/unlock logic
(function() {
  // Tildel data-step attributter til navbar links efter DOM load.
  // bslib genererer nav-links dynamisk, saa vi kan ikke saette dem i R.
  // Tabs identificeres via deres data-value attribut (sat via nav_panel value param).
  var stepMap = { upload: "1", analyser: "2", eksporter: "3" };
  var wizardReady = false;

  // Koe af lock/unlock-beskeder modtaget foer data-step attributter er sat
  var pendingMessages = [];

  function initWizardSteps() {
    var navLinks = document.querySelectorAll('.navbar .nav-link[data-value]');
    navLinks.forEach(function(link) {
      var value = link.getAttribute('data-value');
      if (stepMap[value]) {
        link.setAttribute('data-step', stepMap[value]);
      }
    });

    // Marker som klar og afspil ventende beskeder (atomisk drain)
    wizardReady = true;
    var toApply = pendingMessages.slice();
    pendingMessages = [];
    toApply.forEach(function(msg) {
      applyStepClass(msg.step, msg.action);
    });
  }

  // Kald ved DOM ready og naar Shiny er connected
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initWizardSteps);
  } else {
    initWizardSteps();
  }
  $(document).on('shiny:connected', function() {
    // Re-init efter reconnect (bslib kan re-rendere navbar)
    if (!wizardReady) initWizardSteps();
  });

  // Fælles funktion til at tilføje/fjerne wizard-locked klasse
  function applyStepClass(step, action) {
    var links = document.querySelectorAll('[data-step="' + step + '"]');
    links.forEach(function(link) {
      if (action === 'lock') {
        link.classList.add('wizard-locked');
      } else {
        link.classList.remove('wizard-locked');
      }
    });
  }

  // Tilfoej besked til koe med deduplisering per step
  function queueMessage(step, action) {
    var idx = pendingMessages.findIndex(function(m) { return m.step === step; });
    if (idx !== -1) pendingMessages.splice(idx, 1);
    pendingMessages.push({ step: step, action: action });
  }

  // Lock et wizard-trin (forhindr klik)
  Shiny.addCustomMessageHandler('wizard-lock-step', function(step) {
    if (!wizardReady) { queueMessage(step, 'lock'); return; }
    applyStepClass(step, 'lock');
  });

  // Unlock et wizard-trin (tillad klik)
  Shiny.addCustomMessageHandler('wizard-unlock-step', function(step) {
    if (!wizardReady) { queueMessage(step, 'unlock'); return; }
    applyStepClass(step, 'unlock');
  });

  // Marker et wizard-trin som gennemfoert (groent checkmark)
  Shiny.addCustomMessageHandler('wizard-complete-step', function(step) {
    var links = document.querySelectorAll('[data-step="' + step + '"]');
    links.forEach(function(link) {
      link.classList.add('wizard-completed');
    });
  });

  // Fjern gennemfoert-markering fra et wizard-trin
  Shiny.addCustomMessageHandler('wizard-uncomplete-step', function(step) {
    var links = document.querySelectorAll('[data-step="' + step + '"]');
    links.forEach(function(link) {
      link.classList.remove('wizard-completed');
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

  // Default aktiv-tilstand for upload- og eksportknapper
  // + Skjul wizard-trin ved start (landing page)
  $(document).on('shiny:connected', function() {
    setTimeout(function() {
      // Landing page: Skjul alle nav-items undtagen startside
      document.querySelectorAll('.navbar .nav-link[data-value]').forEach(function(link) {
        var val = link.getAttribute('data-value');
        if (val && val !== 'start') {
          var item = link.closest('.nav-item');
          if (item) {
            item.classList.add('wizard-nav-item');
            item.style.display = 'none';
          }
        }
      });

      // Upload: "Kopiér & Indsæt data" som default
      var pasteBtn = document.getElementById('show_paste_area');
      if (pasteBtn) pasteBtn.classList.add('upload-btn-active');

      // Eksport: PDF som default + sæt Shiny input-værdi
      var pdfBtn = document.querySelector('[id$="export_fmt_pdf"]');
      if (pdfBtn) pdfBtn.classList.add('upload-btn-active');
      var hiddenInput = document.querySelector('input[id$="export_format"][type="hidden"]');
      if (hiddenInput) Shiny.setInputValue(hiddenInput.id, 'pdf');
    }, 200);
  });

  // Upload-knap aktiv-tilstand switching
  function setActiveUploadBtn(clickedId) {
    document.querySelectorAll('.upload-source-btn').forEach(function(btn) {
      btn.classList.remove('upload-btn-active');
    });
    var clicked = document.getElementById(clickedId);
    if (clicked) clicked.classList.add('upload-btn-active');
  }

  $(document).on('click', '#show_paste_area', function() {
    setActiveUploadBtn('show_paste_area');
  });
  $(document).on('click', '#trigger_file_upload', function() {
    setActiveUploadBtn('trigger_file_upload');
  });
  $(document).on('click', '#load_sample_data', function() {
    setActiveUploadBtn('load_sample_data');
  });
  $(document).on('click', '#clear_saved', function() {
    setActiveUploadBtn('clear_saved');
  });

  // Eksportformat-knap aktiv-tilstand switching (én delegeret handler)
  function setActiveExportBtn(clickedBtn, format) {
    document.querySelectorAll('.export-format-btn').forEach(function(btn) {
      btn.classList.remove('upload-btn-active');
    });
    if (clickedBtn) clickedBtn.classList.add('upload-btn-active');

    var hiddenInput = document.querySelector('input[id$="export_format"][type="hidden"]');
    if (hiddenInput) {
      hiddenInput.value = format;
      Shiny.setInputValue(hiddenInput.id, format);
    }
  }

  $(document).on('click', '.export-format-btn', function() {
    var idMatch = this.id.match(/export_fmt_(\w+)$/);
    if (idMatch) setActiveExportBtn(this, idMatch[1]);
  });

  // Logo-klik: navigér til startside og skjul wizard-trin
  $(document).on('click', '#logo_home_link', function(e) {
    e.preventDefault();
    // Skjul wizard-trin
    document.querySelectorAll('.navbar .nav-item.wizard-nav-item').forEach(function(el) {
      el.style.display = 'none';
    });
    // Navigér til startside via Shiny
    Shiny.setInputValue('main_navbar', 'start');
    // Klik på start-tab linket for at aktivere det
    var startLink = document.querySelector('.navbar .nav-link[data-value="start"]');
    if (startLink) startLink.click();
  });

  // Debounce-feedback: dim plot øjeblikkeligt ved input-ændring
  var plotInputs = [
    'chart_type', 'y_axis_unit', 'x_column', 'y_column',
    'n_column', 'skift_column', 'frys_column', 'target_value',
    'centerline_value'
  ];
  plotInputs.forEach(function(id) {
    $(document).on('change', '#' + id, function() {
      $('.spc-plot-container').addClass('input-pending');
    });
  });
  // Fjern pending-klasse når plot er opdateret
  $(document).on('shiny:value', function(e) {
    if (e.name && e.name.indexOf('spc_plot') !== -1) {
      $('.spc-plot-container').removeClass('input-pending');
    }
  });
})();
