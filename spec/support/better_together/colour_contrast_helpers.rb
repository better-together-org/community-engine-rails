# frozen_string_literal: true

module BetterTogether
  # In-page WCAG contrast checks shared by the colour mode sweeps.
  module ColourContrastHelpers
    # Shared colour maths for the in-page checks.
    def colour_helpers_js
      <<~JS
        const ctx = document.createElement('canvas').getContext('2d', { willReadFrequently: true });
        const rgba = (css) => { ctx.clearRect(0, 0, 1, 1); ctx.fillStyle = '#000'; ctx.fillStyle = css; ctx.fillRect(0, 0, 1, 1);
          const d = ctx.getImageData(0, 0, 1, 1).data; return [d[0], d[1], d[2], d[3] / 255]; };
        const over = (top, bottom) => { const a = top[3];
          return [0, 1, 2].map((i) => top[i] * a + bottom[i] * (1 - a)).concat([1]); };
        const lum = (c) => { const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
          return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]); };
        const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
        const background = (el) => { const stack = [];
          for (let n = el; n; n = n.parentElement) { const s = getComputedStyle(n); stack.push(rgba(s.backgroundColor));
            if (s.backgroundImage !== 'none') return null; if (stack[stack.length - 1][3] === 1) break; }
          return stack.reduceRight((below, layer) => over(layer, below), [255, 255, 255, 1]); };
        const label = (el) => { let s = el.tagName.toLowerCase(); if (el.id) s += '#' + el.id;
          if (typeof el.className === 'string' && el.className.trim()) s += '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.');
          return s; };
      JS
    end

    # Runs in the page. Returns text elements whose contrast with their effective background is below AA. With a
    # scope only the open menu under that selector is read; without one every menu is forced open first.
    def contrast_script(scope = nil)
      <<~JS
        #{colour_helpers_js}
        const failures = [];
        const scope = #{scope.to_json};
        if (!scope) document.querySelectorAll('.dropdown-menu').forEach((menu) => { menu.classList.add('show');
          const first = menu.querySelector('.dropdown-item'); if (first) first.classList.add('active'); });
        const roots = scope ? Array.from(document.querySelectorAll(scope)) : [document.body];
        if (!roots.length) return ['missing ' + scope];
        roots.flatMap((root) => [root, ...root.querySelectorAll('*')]).forEach((el) => {
          if (['SCRIPT', 'STYLE', 'SVG', 'PATH', 'OPTION'].includes(el.tagName.toUpperCase())) return;
          const text = Array.from(el.childNodes).filter((n) => n.nodeType === 3).map((n) => n.textContent.trim()).join(' ').trim();
          const icon = /(^|\\s)(fa|fas|far|fab)(\\s|$)/.test(typeof el.className === 'string' ? el.className : '');
          if (!text && !icon) return;
          const r = el.getBoundingClientRect(); const s = getComputedStyle(el);
          if (r.width < 1 || r.height < 1 || s.visibility === 'hidden' || s.display === 'none' || parseFloat(s.opacity) === 0) return;
          if (el.closest('.visually-hidden, .sr-only, [hidden], .collapse:not(.show), .dropdown-menu:not(.show), .tooltip, [disabled], .visually-hidden-focusable:not(:focus)')) return;
          const bg = background(el); if (!bg) return;
          const fg = over(rgba(s.color), bg);
          const size = parseFloat(s.fontSize); const bold = parseInt(s.fontWeight, 10) >= 700;
          const min = (size >= 24 || (size >= 18.66 && bold) || (icon && !text)) ? 3 : 4.5;
          const value = ratio(fg, bg);
          if (value < min) failures.push(label(el) + ' "' + text.slice(0, 24) + '" ' + value.toFixed(2) + ' < ' + min +
            ' fg ' + s.color + ' bg ' + bg.slice(0, 3).map(Math.round).join(','));
        });
        return failures;
      JS
    end
  end
end
