# frozen_string_literal: true

module BetterTogether
  module Geography
    # The look of a map pin, validated so it can be sent to the browser as data. A point or a type carries
    #
    #   pin: { color: '#2a7', shape: 'rounded', size: 'lg',
    #          icons: ['fa-landmark', { icon: 'fa-star', color: '#ffd43b', style: 'far' }] }
    #
    # One icon is drawn alone; several are stacked (the first is the large base, the others sit on top of it).
    # Colors, icon classes, shapes and sizes outside the allowed forms are dropped, never passed through. The older
    # point keys +color+ and +icon+ still work and are read as a one icon pin.
    class MapPin
      SHAPES = %w[circle rounded square].freeze
      SIZES = %w[sm md lg].freeze
      STYLES = %w[fas far fab fa-solid fa-regular fa-brands].freeze
      DEFAULT_STYLE = 'fas'
      MAX_ICONS = 4
      ICON = /\Afa-[a-z0-9]+(?:-[a-z0-9]+)*\z/
      COLOR = /\A(?:#\h{3,8}|[a-z]{3,20}|rgba?\([\d\s.,%]+\)|var\(--[a-z0-9-]+\))\z/i
      SCALE = (0.3..1.5)

      # A clean hash, or nil when nothing usable was given.
      def self.sanitize(raw)
        return unless raw.respond_to?(:to_h)

        pin = raw.to_h.symbolize_keys
        clean = { color: color(pin[:color]), shape: choice(pin[:shape], SHAPES), size: choice(pin[:size], SIZES),
                  icons: icons(pin[:icons]).presence }.compact
        clean.presence
      end

      # The point with a clean +pin+ (its own, else one built from the legacy +color+ and +icon+ keys).
      def self.point(raw)
        point = raw.to_h.symbolize_keys
        pin = sanitize(point[:pin]) || sanitize(color: point[:color], icons: [point[:icon]].compact)
        point.except(:pin).merge(pin ? { pin: } : {})
      end

      # A map type ({ key:, label:, color: }) with a clean +pin+ when it has one.
      def self.type(raw)
        entry = raw.to_h.symbolize_keys
        pin = sanitize(entry[:pin])
        entry.except(:pin).merge(pin ? { pin: } : {})
      end

      def self.color(value)
        value.to_s.strip.then { |text| text if COLOR.match?(text) }
      end

      def self.choice(value, allowed)
        value.to_s.then { |text| text if allowed.include?(text) }
      end

      def self.icons(list)
        Array(list).first(MAX_ICONS).filter_map { |entry| one_icon(entry) }
      end

      def self.one_icon(entry)
        icon = entry.respond_to?(:to_h) && !entry.is_a?(String) ? entry.to_h.symbolize_keys : { icon: entry }
        name = icon[:icon].to_s
        return unless ICON.match?(name)

        { icon: name, style: choice(icon[:style], STYLES) || DEFAULT_STYLE, color: color(icon[:color]),
          scale: scale(icon[:scale]) }.compact
      end

      def self.scale(value)
        number = Float(value, exception: false)
        number if number && SCALE.cover?(number)
      end

      private_class_method :color, :choice, :icons, :one_icon, :scale
    end
  end
end
