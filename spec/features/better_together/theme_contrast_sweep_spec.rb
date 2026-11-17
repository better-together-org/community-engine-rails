# frozen_string_literal: true

require 'rails_helper'

# Every built-in theme in both colour modes, on a phone and a desktop window, must keep all visible text at WCAG AA
# contrast and paint the header, footer and mobile bar from the theme's own tokens. The mode is independent of the
# theme (a dark theme can be shown in light mode and the reverse), so each combination is checked, not just the
# matching pairs.
RSpec.describe 'Theme and colour mode contrast sweep', :js, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  # Runs in the page. Returns text elements whose contrast with their effective background is below AA.
  def contrast_script
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
      const failures = [];
      document.querySelectorAll('.dropdown-menu').forEach((menu) => { menu.classList.add('show');
        const first = menu.querySelector('.dropdown-item'); if (first) first.classList.add('active'); });
      document.querySelectorAll('body *').forEach((el) => {
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

  # Computed background of a surface as "r,g,b".
  def surface_script
    <<~JS
      const el = document.querySelector(arguments[0]); if (!el) return null;
      const c = document.createElement('canvas').getContext('2d'); c.fillStyle = getComputedStyle(el).backgroundColor; c.fillRect(0, 0, 1, 1);
      return Array.from(c.getImageData(0, 0, 1, 1).data).slice(0, 3).join(',');
    JS
  end

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end

  before do
    Current.platform = host_platform
    manager
  end

  after do
    host_platform.update!(theme: {})
    Current.platform = nil
  end

  def hex_rgb(hex) = hex.delete('#').scan(/../).map { |pair| pair.to_i(16) }.join(',')

  # nil is a platform with no theme selected: the engine and host stylesheets alone.
  def apply_theme(id)
    return unless id

    host_platform.update!(theme: BetterTogether::PlatformThemeConfig.flat_theme(id).merge('preset' => id))
  end

  # Bootstrap fades colours, so a reading taken right after a mode switch would catch the old colour mid-fade.
  def freeze_transitions
    page.execute_script(<<~JS)
      const style = document.createElement('style');
      style.textContent = '*, *::before, *::after { transition: none !important; animation: none !important; }';
      document.head.appendChild(style);
    JS
  end

  def switch_mode(mode)
    page.execute_script("document.documentElement.setAttribute('data-bs-theme', '#{mode}')")
  end

  def surface_problems(config, mode)
    return [] if config.blank?

    tokens = mode == 'dark' ? config.dark_values : config.values
    { '#mobile-bar' => 'navbar_bg', '#app-footer' => 'footer_bg' }.filter_map do |selector, token|
      actual = page.evaluate_script("(function(){ #{surface_script.gsub('arguments[0]', "'#{selector}'")} })()")
      next if actual.nil? || actual == hex_rgb(tokens[token])

      "#{selector} is rgb(#{actual}), theme #{token} is #{tokens[token]}"
    end
  end

  ([nil] + BetterTogether::PlatformThemeConfig.builtin_themes.keys).each do |theme_id|
    { 'desktop' => [1280, 900], 'mobile' => [390, 844] }.each do |device, (width, height)|
      it "#{theme_id || 'no'} theme on #{device} is readable and themed in light and dark mode" do
        apply_theme(theme_id)
        page.current_window.resize_to(width, height)
        capybara_login_as_platform_manager
        visit better_together.settings_path(locale: I18n.default_locale)
        expect(page).to have_css('#app-footer')
        freeze_transitions
        config = host_platform.theme_config

        problems = %w[light dark].flat_map do |mode|
          switch_mode(mode)
          found = page.evaluate_script("(function(){ #{contrast_script} })()")
          (found + surface_problems(config, mode)).uniq.map { |line| "[#{mode}] #{line}" }
        end

        expect(problems).to be_empty, "#{problems.size} problems:\n#{problems.join("\n")}"
      end
    end
  end
end
