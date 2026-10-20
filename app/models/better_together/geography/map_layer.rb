# frozen_string_literal: true

module BetterTogether
  module Geography
    # A data layer drawn on a shared map together with the attribution its data requires. The attribution travels with
    # the layer, so every map that draws it credits the source with no per-map step. Host apps register layers once
    # (MapLayer.register) and maps refer to them by key; a mappable can offer layers through #map_layers.
    class MapLayer
      ATTRIBUTES = %i[key label attribution attribution_url licence licence_url geojson url style].freeze
      DEFAULT_STYLE = { color: '#0d6efd', weight: 2, fillOpacity: 0.08 }.freeze

      attr_reader(*ATTRIBUTES)

      class << self
        def register(key, **attributes)
          registry[key.to_s] = new(key:, **attributes)
        end

        def find(key)
          registry[key.to_s]
        end

        def clear_registry!
          registry.clear
        end

        # Accepts layers, registered keys, or attribute hashes; unknown keys are skipped.
        def resolve(*entries)
          entries.flatten.compact.filter_map do |entry|
            case entry
            when MapLayer then entry
            when Hash then new(**entry.symbolize_keys)
            else find(entry)
            end
          end.uniq(&:key)
        end

        private

        def registry
          @registry ||= {}
        end
      end

      def initialize(key:, **attributes)
        @key = key.to_s
        attributes.slice(*ATTRIBUTES).each { |name, value| instance_variable_set(:"@#{name}", value) }
        @label ||= @key.humanize
        @style ||= DEFAULT_STYLE
      end

      # The credit line Leaflet shows in the map's attribution control while the layer is on the map.
      def attribution_html
        parts = [credit(attribution, attribution_url)]
        parts << "(#{credit(licence, licence_url)})" if licence.present?
        parts.compact_blank.join(' ').html_safe # rubocop:disable Rails/OutputSafety -- every part is escaped in #credit
      end

      def as_json(*)
        { key:, label:, style:, geojson:, url:, attribution: attribution_html }.compact.deep_stringify_keys
      end

      private

      def credit(text, link)
        return if text.blank?
        return ERB::Util.html_escape(text) unless safe_link?(link)

        %(<a href="#{ERB::Util.html_escape(link)}" target="_blank" rel="noopener">#{ERB::Util.html_escape(text)}</a>)
      end

      def safe_link?(link)
        link.to_s.match?(%r{\Ahttps?://})
      end
    end
  end
end
