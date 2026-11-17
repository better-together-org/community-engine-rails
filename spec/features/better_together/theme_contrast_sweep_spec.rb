# frozen_string_literal: true

require 'rails_helper'

# Every built-in theme in both colour modes, on a phone and a desktop window, must keep all visible text at WCAG AA
# contrast and paint the header, footer and mobile bar from the theme's own tokens. The mode is independent of the
# theme (a dark theme can be shown in light mode and the reverse), so each combination is checked, not just the
# matching pairs.
RSpec.describe 'Theme and colour mode contrast sweep', :js, :no_auth, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

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
      const root = scope ? document.querySelector(scope) : document.body;
      if (!root) return ['missing ' + scope];
      [root, ...root.querySelectorAll('*')].forEach((el) => {
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

  # Helpers for the header menu sweep below.
  def inject_host_css
    page.execute_script(<<~JS, host_menu_css)
      const style = document.createElement('style'); style.id = 'spec-host-menu-css'; style.textContent = arguments[0];
      const anchor = document.querySelector('#platform-theme-style, #user-theme-style');
      anchor ? anchor.before(style) : document.head.appendChild(style);
    JS
  end

  def apply_personal_theme(id)
    host_platform.update!(allow_user_themes: true)
    manager.person.update!(theme: id)
  end

  def open_menu(toggle, menu)
    find(toggle).click unless page.has_css?("#{menu}.show", wait: 0)
    expect(page).to have_css("#{menu}.show")
  end

  def menu_problems(scope)
    page.evaluate_script("(function(){ #{contrast_script(scope)} })()")
  end

  # Text contrast of one item, and whether its own background stands apart from the menu behind it.
  def item_state(selector)
    page.evaluate_script(<<~JS)
      (function(){ #{colour_helpers_js}
        const el = document.querySelector(#{selector.to_json}); if (!el) return null;
        const bg = background(el); const menu = background(el.closest('.dropdown-menu'));
        const fg = over(rgba(getComputedStyle(el).color), bg);
        return { text: ratio(fg, bg), surface: ratio(bg, menu), marker: getComputedStyle(el).boxShadow !== 'none' };
      })()
    JS
  end

  # A highlighted item needs readable text and must stand apart from the menu (a marker or a tinted surface).
  def highlight_problems(label, state)
    problems = []
    problems << "#{label} text #{state['text'].round(2)}" if state['text'] < 4.5
    problems << "#{label} not highlighted (#{state['surface'].round(2)})" unless state['marker'] || state['surface'] >= 1.1
    problems
  end

  def locale_problems
    problems = menu_problems('#locale-switcher .dropdown-menu')
    problems += highlight_problems('current language', item_state('#locale-switcher .dropdown-item.active'))
    find('#locale-switcher .dropdown-item:not(.active)', match: :first).hover
    expect(page).to have_css('#locale-switcher .dropdown-item:not(.active):hover')
    problems + highlight_problems('hovered language', item_state('#locale-switcher .dropdown-item:not(.active):hover'))
  end

  # The Host toggle against a sibling item: same left edge and padding, and its text starts at the left (not centred).
  def host_alignment_problems
    page.evaluate_script(<<~JS)
      (function(){ const box = (el) => { const r = el.getBoundingClientRect(); const s = getComputedStyle(el);
        const range = document.createRange(); const text = Array.from(el.childNodes).find((n) => n.nodeType === 3 && n.textContent.trim());
        range.selectNodeContents(text); return { left: r.left + parseFloat(s.paddingLeft), text: range.getBoundingClientRect().left,
          padding: s.paddingLeft }; };
        const host = box(document.querySelector('#host-nav-item .nav-link.dropdown-toggle'));
        const item = box(document.querySelector('#user-nav .dropdown-item[data-identifier="conversations"]'));
        const problems = [];
        if (Math.abs(host.left - item.left) > 1) problems.push('Host starts at ' + Math.round(host.left) + ', items at ' + Math.round(item.left));
        if (host.padding !== item.padding) problems.push('Host padding ' + host.padding + ', items ' + item.padding);
        if (host.text - host.left > 30) problems.push('Host text sits ' + Math.round(host.text - host.left) + 'px in');
        return problems; })()
    JS
  end

  def all_menu_problems
    problems = []
    open_menu('#userNavbarDropdownMenuLink', '#user-nav > .dropdown-menu')
    open_menu('#host-nav-item .dropdown-toggle', '#host-nav-item .dropdown-menu')
    problems += menu_problems('#user-nav > .dropdown-menu') + host_alignment_problems
    open_menu('#notification-icon', '#notification-list')
    expect(page).to have_css('#notification-list [data-better-together--lazy-notifications-target="content"] *')
    problems += menu_problems('#notification-list')
    open_menu('#localeDropdownMenuLink', '#locale-switcher .dropdown-menu')
    problems + locale_problems
  end

  def open_settings_as_manager
    capybara_login_as_platform_manager
    visit better_together.settings_path(locale: I18n.default_locale)
    expect(page).to have_css('#host-nav-item', visible: :all)
    freeze_transitions
  end

  def sweep_menus(host_css:)
    open_settings_as_manager
    inject_host_css if host_css
    %w[light dark].flat_map do |mode|
      switch_mode(mode)
      all_menu_problems.uniq.map { |line| "[#{mode}] #{line}" }
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

  # The header rules of the Better Together host app (theme.scss), which paint header menus with the header colour.
  # They load before the theme styles, like any host stylesheet.
  def host_menu_css
    <<~CSS
      #main-nav { position: sticky; top: 0; z-index: 1000; background: var(--bts-navbar-bg, #b1e3cc); color: var(--bts-navbar-link, #222); }
      #main-nav a:not(.dropdown-item) { color: var(--bts-navbar-link, #222); }
      #main-nav .dropdown-menu { background: var(--bts-navbar-bg, #b1e3cc); }
      .navbar-nav .nav-link { color: var(--bts-navbar-link, #42b983); padding: 5px 10px; border-bottom: 4px solid transparent; }
      .navbar-nav .nav-link:hover, .navbar-nav .nav-link:focus { border-bottom: 4px solid var(--bts-navbar-link, #42b983); }
      [data-bs-theme='dark'] #main-nav { background: var(--bts-navbar-bg, #133526); color: var(--bts-navbar-link, #f0f0f0); }
      [data-bs-theme='dark'] #main-nav a:not(.dropdown-item) { color: var(--bts-navbar-link, #f0f0f0); }
      [data-bs-theme='dark'] #main-nav .dropdown-menu { background: var(--bts-navbar-bg, #133526); }
      [data-bs-theme='dark'] .navbar-nav .nav-link { color: var(--bts-navbar-link, #8ed5b5); }
    CSS
  end

  # The header menus only render their colours once opened, so each one is opened for real: the account menu with
  # its Host submenu, notifications and the language switcher (with a hovered and the current item).
  ([nil] + BetterTogether::PlatformThemeConfig.builtin_themes.keys).each do |theme_id|
    { 'platform' => :apply_theme, 'personal' => :apply_personal_theme }.each do |source, applier|
      next if theme_id.nil? && source == 'personal'

      { 'desktop' => [1280, 900], 'mobile' => [390, 844] }.each do |device, (width, height)|
        [false, true].each do |host_css|
          it "#{theme_id || 'no'} theme as #{source} theme on #{device}#{' under a host menu colour' if host_css} " \
             'keeps every menu readable in light and dark mode' do
            send(applier, theme_id)
            page.current_window.resize_to(width, height)
            problems = sweep_menus(host_css:)

            expect(problems).to be_empty, "#{problems.size} problems:\n#{problems.join("\n")}"
          end
        end
      end
    end
  end
end
