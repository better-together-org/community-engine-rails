# frozen_string_literal: true

module BetterTogether
  # Per-platform theme settings stored in Platform#settings['theme'].
  # Sanitizes and validates values, computes WCAG contrast ratios and renders
  # the CSS custom properties that the platform Css block can still override.
  class PlatformThemeConfig # rubocop:disable Metrics/ClassLength
    COLOR_KEYS = %w[primary primary_text accent accent_dark page_bg band body_text link
                    navbar_bg navbar_link footer_bg footer_link].freeze
    THEMES_PATH = BetterTogether::Engine.root.join('config/platform_themes.yml')
    FONT_STACKS = {
      'system' => 'system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      'tahoma' => 'Tahoma, Verdana, Segoe, sans-serif',
      'georgia' => 'Georgia, "Times New Roman", Times, serif',
      'monospace' => 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace'
    }.freeze
    RADII = { 'none' => '0', 'small' => '0.25rem', 'medium' => '0.5rem', 'large' => '1rem' }.freeze
    KEYS = (COLOR_KEYS + %w[font radius preset]).freeze
    HEX = /\A#\h{6}\z/
    AA_NORMAL = 4.5
    AAA_NORMAL = 7.0
    AA_NON_TEXT = 3.0
    # Foreground, background and the minimum ratio: 4.5 for text, 3 for the accent used as a focus ring.
    CONTRAST_PAIRS = [
      ['primary_text', 'primary', AA_NORMAL], ['navbar_link', 'navbar_bg', AA_NORMAL],
      ['footer_link', 'footer_bg', AA_NORMAL], ['body_text', 'page_bg', AA_NORMAL],
      ['body_text', 'band', AA_NORMAL], ['link', 'page_bg', AA_NORMAL], ['link', 'band', AA_NORMAL],
      ['accent_dark', 'page_bg', AA_NORMAL], ['accent', 'page_bg', AA_NON_TEXT]
    ].freeze
    DEFAULT_PAGE_BG = '#ffffff'

    THEME_ID_FORMAT = /\A[a-z][a-z0-9_]*\z/

    # All selectable themes keyed by id: the built-ins (config/platform_themes.yml), then the host app's
    # config/platform_themes.yml, then themes added with .register_theme. Host themes may not reuse a built-in id.
    def self.themes
      builtin_themes.merge(registered_themes).freeze
    end

    def self.builtin_themes
      @builtin_themes ||= YAML.load_file(THEMES_PATH).freeze
    end

    def self.registered_themes
      @registered_themes ||= {}
    end

    # Adds a theme for host apps and extension gems. tokens use the same keys as the built-ins; name and
    # description are optional literals, otherwise better_together.platforms.theme.presets.<id>.* is used.
    def self.register_theme(id, tokens, name: nil, description: nil)
      id = id.to_s
      clean = validated_theme_tokens(id, tokens)
      theme_labels[id] = { name:, description: }.compact
      registered_themes[id] = clean.freeze
    end

    def self.validated_theme_tokens(id, tokens)
      raise ArgumentError, "invalid theme id #{id.inspect}" unless THEME_ID_FORMAT.match?(id)
      raise ArgumentError, "theme id #{id.inspect} is a built-in theme" if builtin_themes.key?(id)

      clean = sanitize(tokens).except('preset')
      problem = theme_problem(clean)
      raise ArgumentError, "theme #{id}: #{problem}" if problem

      clean
    end

    def self.theme_problem(clean)
      invalid = errors_for(clean).map(&:first)
      missing = COLOR_KEYS - clean.keys
      return "invalid #{invalid.join(', ')}" if invalid.any?

      "missing #{missing.join(', ')}" if missing.any?
    end

    # Loads a YAML file of themes (id => tokens, optional name/description keys), as the built-in file does.
    def self.register_themes_from(path)
      YAML.safe_load_file(path).each do |id, tokens|
        tokens = tokens.dup
        register_theme(id, tokens, name: tokens.delete('name'), description: tokens.delete('description'))
      end
    end

    def self.theme_labels
      @theme_labels ||= {}
    end

    def self.theme_name(id)
      theme_labels.dig(id.to_s, :name) ||
        I18n.t("better_together.platforms.theme.presets.#{id}.name", default: id.to_s.humanize)
    end

    def self.theme_description(id)
      theme_labels.dig(id.to_s, :description) ||
        I18n.t("better_together.platforms.theme.presets.#{id}.description", default: '')
    end

    # Contrast pairs of a theme below their minimum, as [foreground, background, ratio]; use in host specs.
    def self.contrast_failures(id)
      tokens = themes.fetch(id.to_s)
      CONTRAST_PAIRS.filter_map do |fg, bg, minimum|
        ratio = contrast_ratio(tokens[fg], tokens[bg])
        [fg, bg, ratio] if ratio.nil? || ratio < minimum
      end
    end

    def self.reset_registered_themes!
      @registered_themes = {}
      @theme_labels = {}
    end

    # Normalizes raw form or stored values to a hash with only known keys and non-blank values.
    def self.sanitize(raw)
      hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      hash.stringify_keys.slice(*KEYS).transform_values { |v| v.to_s.strip.downcase }.compact_blank
    end

    # The [key, value] pairs that are not acceptable.
    def self.errors_for(values)
      values.select { |key, value| invalid_value?(key, value) }.to_a
    end

    def self.invalid_value?(key, value)
      case key
      when 'preset' then themes.keys.exclude?(value)
      when 'font' then FONT_STACKS.exclude?(value)
      when 'radius' then RADII.exclude?(value)
      else !HEX.match?(value)
      end
    end

    # WCAG 2.x contrast ratio between two #rrggbb colours, or nil when either is invalid.
    def self.contrast_ratio(foreground, background)
      return unless HEX.match?(foreground.to_s) && HEX.match?(background.to_s)

      lighter, darker = [luminance(foreground), luminance(background)].sort.reverse
      ((lighter + 0.05) / (darker + 0.05)).round(2)
    end

    def self.luminance(hex)
      r, g, b = hex.delete('#').scan(/../).map { |c| channel(c.hex / 255.0) }
      (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    end

    def self.channel(value)
      value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
    end

    RULES = {
      'primary' => ':root { --bs-primary: var(--bts-primary); } ' \
                   '.btn-primary { --bs-btn-bg: var(--bts-primary); --bs-btn-border-color: var(--bts-primary); ' \
                   '--bs-btn-color: var(--bts-primary-text, #fff); } ' \
                   '.badge.text-bg-primary, .badge.bg-primary { background-color: var(--bts-primary) !important; ' \
                   'color: var(--bts-primary-text, #fff) !important; }',
      'accent' => ':focus-visible { outline: 2px solid var(--bts-accent); outline-offset: 2px; } ' \
                  '.alert-primary { --bs-alert-border-color: var(--bts-accent); }',
      'accent_dark' => '.btn-secondary { --bs-btn-bg: var(--bts-accent-dark); --bs-btn-border-color: var(--bts-accent-dark); ' \
                       '--bs-btn-color: var(--bts-page-bg, #fff); }',
      'page_bg' => ':root { --bs-body-bg: var(--bts-page-bg); } body { background-color: var(--bts-page-bg); }',
      'link' => ':root { --bs-link-color: var(--bts-link); }',
      'body_text' => ':root { --bs-body-color: var(--bts-body-text); } body { color: var(--bts-body-text); }',
      'band' => '.bg-light { background-color: var(--bts-band) !important; } ' \
                '.alert-primary { --bs-alert-bg: var(--bts-band); --bs-alert-color: var(--bts-body-text); }',
      'navbar_bg' => '.navbar { background-color: var(--bts-navbar-bg); }',
      'navbar_link' => '.navbar { --bs-navbar-color: var(--bts-navbar-link); --bs-navbar-brand-color: var(--bts-navbar-link); }',
      'footer_bg' => 'footer { background-color: var(--bts-footer-bg); }',
      'footer_link' => 'footer a { color: var(--bts-footer-link); }',
      'font' => 'body { font-family: var(--bts-font); }',
      'radius' => ':root { --bs-border-radius: var(--bts-radius); }'
    }.freeze

    attr_reader :values

    def initialize(raw = {})
      @values = self.class.sanitize(raw)
    end

    def blank? = values.empty?

    def [](key) = values[key.to_s]

    # Pairs below their minimum, as [foreground_key, background_key, ratio]; unset pairs are skipped.
    def low_contrast_pairs
      CONTRAST_PAIRS.filter_map do |fg, bg, minimum|
        ratio = self.class.contrast_ratio(self[fg], self[bg] || (DEFAULT_PAGE_BG if bg == 'page_bg'))
        [fg, bg, ratio] if ratio && ratio < minimum
      end
    end

    def css_variables
      vars = values.slice(*COLOR_KEYS).transform_keys { |k| "--bts-#{k.dasherize}" }
      vars['--bts-font'] = FONT_STACKS[self['font']] if self['font']
      vars['--bts-radius'] = RADII[self['radius']] if self['radius']
      vars
    end

    # Style rules: variables on :root plus the Bootstrap 5.3 hooks that consume them.
    def to_css(banner_url: nil)
      vars = css_variables
      vars['--bts-header-banner'] = "url(\"#{banner_url}\")" if banner_url.present?
      return '' if vars.empty?

      declarations = vars.map { |name, value| "#{name}: #{value};" }.join(' ')
      ":root { #{declarations} }\n#{consumer_rules}"
    end

    private

    def consumer_rules
      RULES.slice(*values.keys).values.join("\n")
    end
  end
end
