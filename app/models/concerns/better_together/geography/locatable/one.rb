# frozen_string_literal: true

module BetterTogether
  module Geography
    module Locatable
      # Configures locatables with one location
      module One
        extend ActiveSupport::Concern

        included do
          # Any Locatable::One includer is also mappable — its single assigned
          # `location` is rendered via `leaflet_points`/`spaces` below, delegated
          # to by BetterTogether::Geography::Map#leaflet_points.
          include ::BetterTogether::Geography::Mappable

          has_one :location,
                  class_name: 'BetterTogether::Geography::LocatableLocation',
                  as: :locatable

          # Reject nested location attributes when all relevant fields are blank so
          # we don't build an invalid empty LocatableLocation during create/update.
          # Only reject when this is a new nested record (no id) and all meaningful
          # fields are blank. Persisted records with blank fields should be allowed
          # through so they can be marked for destruction by the model callback.
          accepts_nested_attributes_for :location,
                                        allow_destroy: true,
                                        reject_if: lambda { |attrs|
                                          attrs.blank? || (
                                            # rubocop:todo Layout/LineLength
                                            attrs['id'].blank? && attrs['name'].blank? && attrs['location_id'].blank? && attrs['location_type'].blank?
                                            # rubocop:enable Layout/LineLength
                                          )
                                        }
        end

        class_methods do
          def extra_permitted_attributes
            super + [{
              location_attributes:
                BetterTogether::Geography::LocatableLocation.permitted_attributes(id: true,
                                                                                  destroy: true)
            }]
          end
        end

        # A single leaflet point for the assigned structured location, or an empty
        # array when there's no location, a free-text/simple location (no
        # coordinates), or the location's space isn't geocoded yet.
        def leaflet_points
          point = location&.location&.to_leaflet_point
          return [] unless point

          place_link = "<a href='#{locatable_map_url}' class='text-decoration-none'><strong>#{self}</strong></a>"

          [point.merge(label: place_link, popup_html: "#{place_link}<br>#{location.display_name}")]
        end

        def spaces
          [location&.location&.space].compact
        end

        private

        def locatable_map_url
          BetterTogether::Engine.routes.url_helpers.polymorphic_path(self, locale: I18n.locale)
        rescue NoMethodError
          Rails.application.routes.url_helpers.polymorphic_path(self, locale: I18n.locale)
        end
      end
    end
  end
end
