// In-page hook, contract "blackbox-v7". It only watches the DOM, so it works on any CerebroNexus
// version. The KPI (visual_complete_ms) is not measured here: it comes from screenshots taken by
// measure_session.R, because the DOM cannot tell when a plot has finished drawing. This hook
// supplies the rest:
//   loader_ms    how long a loading card/overlay was on screen (exact, from the DOM)
//   visible_ms   last DOM change inside the page's tab pane   (diagnostic)
//   settled_ms   last DOM change anywhere or long task          (diagnostic: includes work that
//                happens after the page already looks finished)
//   done/stuck   when to stop waiting
//   error        an output error or a lost connection on screen when the page is done: the page is
//                then not counted as finished, however fast it was
// and the in-page actions (cb.actions): each finds its control, prepares an argument that is not the
// current value, and performs one user action. A control that is not there is "unavailable".
(function () {
  if (window.__cb) return;
  var cb = window.__cb = {
    clickT: 0, paneLast: 0, anyLast: 0, busy: false, pane: null, active: false, loaderMs: 0, lastCheckT: 0, raf: 0
  };
  var now = function () { return performance.now(); };

  function inPane(node) {
    if (!cb.pane) return false;
    var el = node && node.nodeType === 1 ? node : (node && node.parentElement);
    return !!(el && cb.pane.contains(el));
  }
  function loaderVisible() {
    var l = document.getElementById('cerebro-page-loader');
    if (l && !l.hidden && l.classList.contains('is-visible')) return true;
    var d = document.getElementById('cerebro-dataset-loading');
    if (d && !d.hidden && d.getClientRects().length > 0) return true;
    return false;
  }
  function loop() {
    if (!cb.active) return;
    var t = now();
    if (loaderVisible() && cb.lastCheckT) cb.loaderMs += t - cb.lastCheckT;
    cb.lastCheckT = t;
    cb.raf = requestAnimationFrame(loop);
  }

  function start() {
    if (!window.jQuery) return setTimeout(start, 20);
    jQuery(document).on('shiny:busy', function () { cb.busy = true; cb.anyLast = now(); });
    jQuery(document).on('shiny:idle', function () { cb.busy = false; cb.anyLast = now(); });
  }
  start();

  new MutationObserver(function (muts) {
    var t = now();
    for (var i = 0; i < muts.length; i++) {
      var m = muts[i];
      if (m.type === 'attributes' && m.attributeName === 'style' && m.target.classList &&
          m.target.classList.contains('shiny-notification')) continue;
      cb.anyLast = t;
      if (cb.active && (inPane(m.target) || cb.pane === m.target)) cb.paneLast = t;
    }
  }).observe(document, { childList: true, subtree: true, attributes: true, characterData: true });
  try {
    new PerformanceObserver(function (list) {
      list.getEntries().forEach(function (e) {
        var end = e.startTime + e.duration;
        if (end > cb.anyLast) cb.anyLast = end;
      });
    }).observe({ entryTypes: ['longtask'] });
  } catch (e) {}

  cb.tabs = function () {
    var out = [];
    document.querySelectorAll('ul.sidebar-menu a[data-value]').forEach(function (a) {
      var li = a.closest('li');
      if (a.offsetParent !== null && !(li && li.classList.contains('hidden'))) out.push(a.getAttribute('data-value'));
    });
    return JSON.stringify(out);
  };
  cb.begin = function (name, isInitial) {
    cancelAnimationFrame(cb.raf);
    cb.pane = document.getElementById('shiny-tab-' + name);
    cb.active = true;
    cb.clickT = now(); cb.paneLast = cb.clickT; cb.anyLast = cb.clickT; cb.loaderMs = 0; cb.lastCheckT = cb.clickT;
    if (!isInitial) {
      var a = document.querySelector('ul.sidebar-menu a[data-value="' + name + '"]');
      if (a) a.click();
    }
    cb.raf = requestAnimationFrame(loop);
    return true;
  };
  cb.end = function () { cb.active = false; cancelAnimationFrame(cb.raf); return true; };

  function visible(el) { return !!el && el.getClientRects().length > 0; }
  function errorText(pane) {
    var lost = document.getElementById('shiny-disconnected-overlay');
    if (lost) return 'disconnected';
    var errs = pane ? pane.querySelectorAll('.shiny-output-error:not(.shiny-output-error-validation)') : [];
    for (var i = 0; i < errs.length; i++) if (visible(errs[i])) return (errs[i].textContent || 'output error').trim().slice(0, 200);
    var notes = document.querySelectorAll('.shiny-notification-error');
    for (var j = 0; j < notes.length; j++) if (visible(notes[j])) return (notes[j].textContent || 'error notification').trim().slice(0, 200);
    return '';
  }

  // ---- in-page actions ------------------------------------------------------------------------
  // The value an action switches to is chosen the same way on every revision (the next colour
  // column, the alphabetically first gene that is not shown), and returned as `arg` so that a run
  // can tell when two revisions did different work.
  function selectizeOf(id) { var el = document.getElementById(id); return el && el.selectize ? el.selectize : null; }
  // The option after the current one (wrapping), skipping disabled options and those `skip` rejects.
  function nextChoice(id, skip) {
    var s = selectizeOf(id), el = document.getElementById(id);
    if (!el) return null;
    var values = s ? Object.keys(s.options).filter(function (v) { var o = s.options[v]; return !o.disabled && !(skip && skip(o)); })
                       .sort(function (a, b) { return (s.options[a].$order || 0) - (s.options[b].$order || 0); })
                   : Array.prototype.filter.call(el.options, function (o) { return !o.disabled && !(skip && skip(o)); })
                       .map(function (o) { return o.value; });
    var cur = s ? String(s.getValue()) : el.value;
    var i = values.indexOf(cur);
    return values.length > 1 ? values[(i + 1) % values.length] : null;
  }
  function choose(id, value) {
    var s = selectizeOf(id), el = document.getElementById(id);
    if (s) s.setValue(value); else { el.value = value; if (window.jQuery) jQuery(el).trigger('change'); else el.dispatchEvent(new Event('change', { bubbles: true })); }
  }
  function zoomButton(page) {
    var pane = document.getElementById('shiny-tab-' + page);
    if (!pane) return null;
    var c = pane.querySelectorAll('[data-act="zin"], .modebar-btn[data-attr="zoom"][data-val="in"]');
    for (var i = 0; i < c.length; i++) if (visible(c[i])) return c[i];
    return null;
  }
  // An action that switches a select to its next option: page, select id, optional option filter.
  function selectAction(page, id, skip) {
    return {
      page: page,
      prep: function () { var v = nextChoice(id, skip); return v === null ? { available: false } : { ready: true, arg: v }; },
      run: function (arg) { choose(id, arg); }
    };
  }
  // Like selectAction, over several selects: the first of `ids` that has another option is switched
  // (a dataset with one grouping or one FOV per sample still exercises the page). arg is "id=value".
  function firstSelectAction(page, ids) {
    return {
      page: page,
      prep: function () {
        for (var i = 0; i < ids.length; i++) {
          var v = nextChoice(ids[i]);
          if (v !== null) return { ready: true, arg: ids[i] + '=' + v };
        }
        return { available: false };
      },
      run: function (arg) { var k = arg.indexOf('='); choose(arg.slice(0, k), arg.slice(k + 1)); }
    };
  }
  // Immune repertoire: the tab after the active one.
  function nextTab() {
    var tabs = Array.prototype.filter.call(document.querySelectorAll('#ir_tabs a[data-value]'), visible);
    if (tabs.length < 2) return null;
    var i = tabs.findIndex(function (a) { return a.parentElement.classList.contains('active') || a.classList.contains('active'); });
    return tabs[(i + 1) % tabs.length];
  }
  // Overview: a lasso over the middle of the projection, drawn with the mouse events the cell view
  // listens to (mousedown on the panel, mousemove and mouseup on the window).
  function overviewCanvas() {
    var pane = document.getElementById('shiny-tab-overview');
    var cs = pane ? pane.querySelectorAll('.cv-pane .cv-canvas-wrap canvas, .cv-pane canvas') : [];
    for (var i = 0; i < cs.length; i++) if (visible(cs[i]) && cs[i].width > 0) return cs[i];
    return null;
  }
  function lasso(canvas) {
    var r = canvas.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2;
    var rx = r.width * 0.2, ry = r.height * 0.2;
    function ev(type, x, y, target) {
      (target || window).dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, view: window,
        clientX: x, clientY: y, button: 0, buttons: type === 'mouseup' ? 0 : 1 }));
    }
    ev('mousedown', cx + rx, cy, canvas);
    for (var k = 1; k <= 24; k++) {
      var a = 2 * Math.PI * k / 24;
      ev('mousemove', cx + rx * Math.cos(a), cy + ry * Math.sin(a));
    }
    ev('mouseup', cx + rx, cy);
  }
  // A shinyWidgets radio group: the button that is not checked (wrapping), clicked like a user would.
  function otherRadio(id) {
    var el = document.getElementById(id);
    var r = el ? Array.prototype.filter.call(el.querySelectorAll('input[type="radio"]'), function (x) { return !x.disabled; }) : [];
    if (r.length < 2 || !visible(el)) return null;
    var i = r.findIndex(function (x) { return x.checked; });
    return r[(i + 1) % r.length];
  }
  function radioAction(page, id) {
    return {
      page: page,
      prep: function () { var x = otherRadio(id); return x ? { ready: true, arg: x.value } : { available: false }; },
      run: function (arg) {
        var x = document.querySelector('#' + id + ' input[type="radio"][value="' + arg.replace(/"/g, '\\"') + '"]');
        var lbl = x.closest('label'); (lbl || x).click();
      }
    };
  }
  // A checkbox or switch: flip it.
  function toggleAction(page, id) {
    return {
      page: page,
      prep: function () { var el = document.getElementById(id); return el && visible(el.closest('.form-group') || el) ? { ready: true, arg: el.checked ? 'off' : 'on' } : { available: false }; },
      run: function () { document.getElementById(id).click(); }
    };
  }
  // Dataset menu (only there when the server has more than one CRB): switch away to the second
  // dataset, then back to the one the session started with.
  var homeDataset = null;
  var geneQuery = 0, geneQueries = ['a', 'e', 'c'];
  cb.actions = {
    'groups.group': selectAction('groups', 'groups_selected_group'),
    'groups.plot_type': radioAction('groups', 'groups_by_other_group_plot_type'),
    'groups.percent': toggleAction('groups', 'groups_by_other_group_show_as_percent'),
    'markerGenes.table': firstSelectAction('markerGenes', ['marker_genes_selected_table', 'marker_genes_selected_method']),
    'mostExpressedGenes.group': selectAction('mostExpressedGenes', 'most_expressed_genes_selected_group'),
    'enrichedPathways.table': firstSelectAction('enrichedPathways', ['enriched_pathways_selected_table', 'enriched_pathways_selected_method']),
    'trajectory.colour_by': selectAction('trajectory', 'trajectory_point_color'),
    'spatial.section': firstSelectAction('spatial', ['spatial_projection_to_display', 'spatial_projection_sample']),
    'extra_material.content': firstSelectAction('extra_material', ['extra_material_selected_content', 'extra_material_selected_file', 'extra_material_selected_category']),
    'hla_tcr_motifs.colour_by': selectAction('hla_tcr_motifs', 'hla_color_by'),
    'trekker.colour_by': selectAction('trekker', 'trekker_mode'),
    'coordinated_views.colour_by': selectAction('coordinated_views', 'cv-pick-color', function (o) { return o.optgroup === 'Expression'; }),
    'immune_repertoire.tab': {
      page: 'immune_repertoire',
      prep: function () { var a = nextTab(); return a ? { ready: true, arg: a.getAttribute('data-value') } : { available: false }; },
      run: function (arg) { document.querySelector('#ir_tabs a[data-value="' + arg + '"]').click(); }
    },
    'overview.lasso': {
      page: 'overview',
      prep: function () { return overviewCanvas() ? { ready: true, arg: 'middle 40%' } : { available: false }; },
      run: function () { lasso(overviewCanvas()); }
    },
    'loadData.switch': {
      page: 'loadData',
      prep: function () {
        var s = selectizeOf('crb_file_selector');
        if (!s) return { available: false };
        homeDataset = String(s.getValue());
        var v = nextChoice('crb_file_selector');
        return v === null ? { available: false } : { ready: true, arg: v };
      },
      run: function (arg) { choose('crb_file_selector', arg); }
    },
    'loadData.switch_back': {
      page: 'loadData',
      prep: function () {
        var s = selectizeOf('crb_file_selector');
        if (!s || homeDataset === null || String(s.getValue()) === homeDataset) return { available: false };
        return { ready: true, arg: homeDataset };
      },
      run: function (arg) { choose('crb_file_selector', arg); }
    },
    'overview.colour_by': {
      page: 'overview',
      prep: function () { var v = nextChoice('overview_projection_point_color'); return v === null ? { available: false } : { ready: true, arg: v }; },
      run: function (arg) { choose('overview_projection_point_color', arg); }
    },
    'overview.zoom': {
      page: 'overview',
      prep: function () { return zoomButton('overview') ? { ready: true, arg: 'in' } : { available: false }; },
      run: function () { zoomButton('overview').click(); }
    },
    'geneExpression.gene': {
      page: 'geneExpression',
      prep: function () {
        var s = selectizeOf('expression_genes_input');
        if (!s) return { available: false };
        var cur = [].concat(s.getValue() || []);
        var genes = Object.keys(s.options).filter(function (g) { return cur.indexOf(g) < 0; }).sort();
        if (genes.length) return { ready: true, arg: genes[0] };
        // Server-side gene lists load on search: ask for a few genes and look again.
        if (typeof s.settings.load === 'function' && !s.loading && geneQuery < geneQueries.length) {
          var q = geneQueries[geneQuery++];
          s.load(function (callback) { s.settings.load.call(s, q, callback); });
        }
        return { ready: false };
      },
      run: function (arg) { var s = selectizeOf('expression_genes_input'); s.setValue([arg]); }
    },
    // Twelve genes at once (the multi-gene path: separate panels or a mean, depending on the version).
    // Needs at least 2 genes in the box; asks the server-side list for more, as above.
    'geneExpression.genes12': {
      page: 'geneExpression',
      prep: function () {
        var s = selectizeOf('expression_genes_input');
        if (!s) return { available: false };
        var genes = Object.keys(s.options).sort();
        if (genes.length >= 12 || (geneQuery >= geneQueries.length && !s.loading && genes.length >= 2)) {
          return { ready: true, arg: genes.slice(0, 12).join(' ') };
        }
        if (typeof s.settings.load === 'function' && !s.loading && geneQuery < geneQueries.length) {
          var q = geneQueries[geneQuery++];
          s.load(function (callback) { s.settings.load.call(s, q, callback); });
        } else if (typeof s.settings.load !== 'function' && genes.length >= 2) {
          return { ready: true, arg: genes.slice(0, 12).join(' ') };
        }
        return { ready: false };
      },
      run: function (arg) { var s = selectizeOf('expression_genes_input'); s.setValue(arg.split(' ')); }
    }
  };
  cb.actionNames = function () { return JSON.stringify(Object.keys(cb.actions)); };
  cb.actionPage = function (name) { return cb.actions[name].page; };
  cb.actionPrep = function (name) {
    var r = cb.actions[name].prep();
    if (r.available === undefined) r.available = true;
    return JSON.stringify(r);
  };
  // Like begin(), but on the page that is already shown, and the click is the action.
  cb.actionBegin = function (name, arg) {
    cancelAnimationFrame(cb.raf);
    cb.pane = document.getElementById('shiny-tab-' + cb.actions[name].page);
    cb.active = true;
    cb.clickT = now(); cb.paneLast = cb.clickT; cb.anyLast = cb.clickT; cb.loaderMs = 0; cb.lastCheckT = cb.clickT;
    cb.actions[name].run(arg);
    cb.raf = requestAnimationFrame(loop);
    return true;
  };
  // First plot from the start of the page (visit first_plot): called on every frame while the Viewer is
  // loading. It opens the Projection page as soon as the sidebar offers it (the click of a user who is
  // waiting for the plot), from then on reports state() and where the projection canvas is, in viewport
  // pixels: [x, y, width, height]. `click_ms` is the click on the page's own clock, which starts at
  // the navigation (performance.now()).
  cb.fpClickT = 0;
  cb.fpStep = function () {
    if (!cb.fpClickT) {
      var a = document.querySelector('ul.sidebar-menu a[data-value="overview"]');
      if (!a || a.offsetParent === null || !document.getElementById('shiny-tab-overview')) return JSON.stringify({ done: false });
      cb.begin('overview', false);
      cb.fpClickT = cb.clickT;
    }
    var st = JSON.parse(cb.state()), c = overviewCanvas(), r = c ? c.getBoundingClientRect() : null;
    st.click_ms = cb.fpClickT;
    st.rect = r ? [r.left, r.top, r.width, r.height] : null;
    return JSON.stringify(st);
  };
  cb.state = function () {
    var t = now(), pane = cb.pane;
    var hasContent = !!pane && (pane.textContent.trim().length > 0 || !!pane.querySelector('canvas,svg,img,table,.plotly'));
    var shown = !!pane && pane.classList.contains('active');
    var lastChange = Math.max(cb.paneLast, cb.anyLast);
    var quiet = (t - cb.paneLast >= 500) && (t - cb.anyLast >= 500);
    // Shiny's own busy flag can stay set after the server is idle (seen on older versions);
    // a page that has not changed for 15 s while "busy" is reported as stuck, not waited for.
    var stuck = cb.busy && (t - lastChange >= 15000);
    var done = hasContent && shown && quiet && (!cb.busy || stuck);
    return JSON.stringify({
      done: done,
      stuck: stuck,
      error: done ? errorText(pane) : '',
      loader_ms: cb.loaderMs,
      visible_ms: cb.paneLast - cb.clickT,
      settled_ms: lastChange - cb.clickT,
      busy: cb.busy
    });
  };
})();
