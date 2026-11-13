# frozen_string_literal: true

module BetterTogether
  # Per-platform header and footer content and 404 headline sets, kept in
  # Platform#settings['page_content'] as locale keyed hashes.
  class PlatformContentConfig
    HTML_KEYS = %w[header_html footer_html].freeze
    KEYS = (HTML_KEYS + %w[not_found_headlines]).freeze
    MAX_HTML_LENGTH = 5_000
    MAX_HEADLINES = 20
    MAX_HEADLINE_LENGTH = 140

    # Locale keyed hashes limited to known keys and locales; blank entries are dropped.
    def self.sanitize(raw)
      hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      locales = I18n.available_locales.map(&:to_s)
      hash.stringify_keys.slice(*KEYS).transform_values do |by_locale|
        by_locale.to_h.stringify_keys.slice(*locales).transform_values { |v| normalize(v) }.compact_blank
      end.compact_blank
    end

    def self.normalize(value)
      value.is_a?(Array) ? value.map { |v| v.to_s.strip }.compact_blank : value.to_s.strip
    end

    # Human readable problems as [key, locale] pairs.
    def self.errors_for(values)
      values.flat_map do |key, by_locale|
        by_locale.filter_map { |locale, value| [key, locale] if too_big?(key, value) }
      end
    end

    def self.too_big?(key, value)
      return value.size > MAX_HTML_LENGTH if HTML_KEYS.include?(key)

      lines = headline_lines(value)
      lines.size > MAX_HEADLINES || lines.any? { |line| line.size > MAX_HEADLINE_LENGTH }
    end

    def self.headline_lines(value)
      (value.is_a?(Array) ? value : value.to_s.lines).map { |line| line.to_s.strip }.compact_blank
    end

    attr_reader :values

    def initialize(raw = {})
      @values = self.class.sanitize(raw)
    end

    # Text for a key in the given locale, falling back to the default locale.
    def html(key, locale = I18n.locale)
      by_locale = values[key.to_s] || {}
      by_locale[locale.to_s].presence || by_locale[I18n.default_locale.to_s]
    end

    def headlines(locale = I18n.locale)
      by_locale = values['not_found_headlines'] || {}
      self.class.headline_lines(by_locale[locale.to_s].presence || by_locale[I18n.default_locale.to_s])
    end

    def random_headline(locale = I18n.locale)
      headlines(locale).sample
    end
  end
end
