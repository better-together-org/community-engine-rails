# frozen_string_literal: true

module BetterTogether
  # Per-platform theme settings stored in Platform#settings['theme'].
  # Sanitizes and validates values, computes WCAG contrast ratios and renders
  # the CSS custom properties that the platform Css block can still override.
  class PlatformThemeConfig
    COLOR_KEYS = %w[primary primary_text accent accent_dark band body_text link
                    navbar_bg navbar_link footer_bg footer_link].freeze
    FONT_STACKS = {
      'system' => 'system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      'tahoma' => 'Tahoma, Verdana, Segoe, sans-serif',
      'georgia' => 'Georgia, "Times New Roman", Times, serif',
      'monospace' => 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace'
    }.freeze
    RADII = { 'none' => '0', 'small' => '0.25rem', 'medium' => '0.5rem', 'large' => '1rem' }.freeze
    KEYS = (COLOR_KEYS + %w[font radius]).freeze
    HEX = /\A#\h{6}\z/
    AA_NORMAL = 4.5
    # Foreground, background and the setting that names them, checked live in the form.
    CONTRAST_PAIRS = [
      %w[primary_text primary], %w[navbar_link navbar_bg], %w[footer_link footer_bg],
      %w[body_text band], %w[link band]
    ].freeze
    WHITE = '#ffffff'
    PRESETS = {
      'foray' => {
        'primary' => '#243542', 'primary_text' => '#ffffff', 'accent' => '#ee722a', 'accent_dark' => '#b8480f',
        'band' => '#f5f5f5', 'body_text' => '#243542', 'link' => '#b8480f',
        'navbar_bg' => '#243542', 'navbar_link' => '#ffffff', 'footer_bg' => '#243542', 'footer_link' => '#ffffff',
        'font' => 'tahoma'
      }
    }.freeze

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
                   '--bs-btn-color: var(--bts-primary-text, #fff); }',
      'link' => ':root { --bs-link-color: var(--bts-link); }',
      'body_text' => 'body { color: var(--bts-body-text); }',
      'band' => '.bg-light { background-color: var(--bts-band) !important; }',
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

    # Pairs below AA, as [foreground_key, background_key, ratio]; unset pairs are skipped.
    def low_contrast_pairs
      CONTRAST_PAIRS.filter_map do |fg, bg|
        ratio = self.class.contrast_ratio(self[fg], self[bg] || (WHITE if fg == 'link'))
        [fg, bg, ratio] if ratio && ratio < AA_NORMAL
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
