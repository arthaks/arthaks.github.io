document.addEventListener('DOMContentLoaded', function () {
  var journal = document.querySelector('.activity-journal');
  if (!journal) return;
  var prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function revealTarget(hash, smooth) {
    if (!hash) return;
    var target = document.getElementById(hash.slice(1));
    if (!target) return;
    var panel = target.matches('details.month-panel') ? target : target.closest('details.month-panel');
    if (panel) panel.open = true;
    window.requestAnimationFrame(function () {
      target.scrollIntoView({ behavior: smooth && !prefersReducedMotion ? 'smooth' : 'auto', block: 'start' });
    });
  }

  var nav = journal.querySelector('.month-jump-nav');
  if (nav) {
    nav.querySelectorAll('[data-month-target]').forEach(function (link) {
      link.addEventListener('click', function (event) {
        event.preventDefault();
        var hash = link.getAttribute('href');
        history.replaceState(null, '', hash);
        revealTarget(hash, true);
      });
    });
  }

  var layout = journal.querySelector('.calendar-layout');
  if (layout) {
    var year = Number(layout.getAttribute('data-calendar-year'));
    var recordedDates = new Set((layout.getAttribute('data-recorded-dates') || '').split(',').filter(Boolean));
    var grid = layout.querySelector('.contribution-grid');
    var months = layout.querySelector('.calendar-months');
    var firstDay = new Date(year, 0, 1);
    var leadingCells = firstDay.getDay();
    var daysInYear = new Date(year, 1, 29).getMonth() === 1 ? 366 : 365;
    var weekCount = Math.ceil((leadingCells + daysInYear) / 7);
    var monthNames = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    layout.style.setProperty('--calendar-weeks', weekCount);

    monthNames.forEach(function (name, monthIndex) {
      var monthStart = new Date(year, monthIndex, 1);
      var dayOffset = Math.round((Date.UTC(year, monthIndex, 1) - Date.UTC(year, 0, 1)) / 86400000);
      var week = Math.floor((leadingCells + dayOffset) / 7) + 1;
      var label = document.createElement('span');
      label.textContent = name;
      label.style.gridColumn = week + ' / span 4';
      months.appendChild(label);
    });

    for (var blankIndex = 0; blankIndex < leadingCells; blankIndex += 1) {
      var blank = document.createElement('span');
      blank.className = 'calendar-cell is-empty';
      blank.setAttribute('aria-hidden', 'true');
      grid.appendChild(blank);
    }

    function isoDate(date) {
      return date.getFullYear() + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0');
    }

    for (var dayIndex = 0; dayIndex < daysInYear; dayIndex += 1) {
      var date = new Date(year, 0, dayIndex + 1);
      var iso = isoDate(date);
      var recorded = recordedDates.has(iso);
      var cell = document.createElement('span');
      cell.className = 'calendar-cell' + (recorded ? ' is-recorded' : '');
      cell.setAttribute('role', recorded ? 'button' : 'gridcell');
      cell.setAttribute('aria-label', iso + (recorded ? '，有记录' : '，未记录'));
      cell.title = iso + (recorded ? ' · 有记录' : ' · 未记录');
      if (recorded) {
        cell.tabIndex = 0;
        var activate = function (targetDate) {
          var hash = '#day-' + targetDate;
          history.replaceState(null, '', hash);
          revealTarget(hash, true);
        };
        cell.addEventListener('click', activate.bind(null, iso));
        cell.addEventListener('keydown', function (targetDate, event) {
          if (event.key !== 'Enter' && event.key !== ' ') return;
          event.preventDefault();
          activate(targetDate);
        }.bind(null, iso));
      }
      grid.appendChild(cell);
    }
  }

  revealTarget(window.location.hash, false);
});
