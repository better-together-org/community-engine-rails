# frozen_string_literal: true

module BetterTogether
  module Geography
    module Locatable
      # A record with building pins keeps them on its map; one with none shows the place it is located at, when that
      # place is geocoded. Include after the module that defines +leaflet_points+ and +spaces+.
      module LocationMapPoints
        def leaflet_points
          super.presence || located_leaflet_points
        end

        def spaces
          super.presence || [location&.location&.space].compact.select(&:geocoded?)
        end

        private

        def located_leaflet_points
          point = location&.location&.to_leaflet_point
          return [] unless point

          link = "<a href='#{located_map_url}' class='text-decoration-none'><strong>#{ERB::Util.html_escape(to_s)}</strong></a>"
          [point.merge(label: link, popup_html: "#{link}<br>#{ERB::Util.html_escape(location.display_name)}")]
        end

        def located_map_url
          BetterTogether::Engine.routes.url_helpers.polymorphic_path(self, locale: I18n.locale)
        rescue NoMethodError
          Rails.application.routes.url_helpers.polymorphic_path(self, locale: I18n.locale)
        end
      end
    end
  end
end
