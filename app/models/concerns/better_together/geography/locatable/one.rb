# frozen_string_literal: true

module BetterTogether
  module Geography
    module Locatable
      # Configures locatables with one location
      module One
        extend ActiveSupport::Concern

        ADDRESS_FIELDS = %w[name line1 line2 city_name state_province_name postal_code country_name].freeze
        ADDRESS_MATCH_FIELDS = %w[line1 city_name postal_code country_name].freeze

        included do
          include ::BetterTogether::Geography::Locatable::AddressData

          # Any Locatable::One includer is also mappable — its single assigned
          # `location` is rendered via `leaflet_points`/`spaces` below, delegated
          # to by BetterTogether::Geography::Map#leaflet_points.
          include ::BetterTogether::Geography::Mappable
          include ::BetterTogether::Geography::Locatable::LocatedIn

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

          escaped_self = ERB::Util.html_escape(to_s)
          place_link = "<a href='#{locatable_map_url}' class='text-decoration-none'><strong>#{escaped_self}</strong></a>"
          escaped_display_name = ERB::Util.html_escape(location.display_name)

          [point.merge(label: place_link, popup_html: "#{place_link}<br>#{escaped_display_name}")]
        end

        def spaces
          [location&.location&.space].compact
        end

        # Write-only API input: locates the record at a street address, given as a hash or a JSON string (the
        # JSON:API rejects nested objects) with line1, line2, city_name, state_province_name, postal_code,
        # country_name and an optional name for the place. An existing address with the same line1, city, postal
        # code and country is reused; otherwise a public one is created. Blank clears the location.
        def address_data
          nil
        end

        def address_data=(spec)
          @address_data_error = nil
          if spec.blank?
            location&.mark_for_destruction
          else
            locate_at_address(spec)
          end
        rescue JSON::ParserError
          @address_data_error = 'is not valid JSON'
        end

        private

        def address_data_must_be_valid
          errors.add(:address_data, @address_data_error) if @address_data_error
        end

        def locate_at_address(spec)
          attrs = parse_address_data(spec)
          return @address_data_error = 'must be an address with line1' if attrs['line1'].blank?

          name = attrs.delete('name') # a location is shown only when it has a name
          place = location || build_location
          place.assign_attributes(location: address_for(attrs), name: name.presence || place.name)
        end

        def parse_address_data(spec)
          spec = JSON.parse(spec) if spec.is_a?(String)
          spec.to_h.stringify_keys.slice(*ADDRESS_FIELDS).transform_values { |value| value.to_s.strip }.compact_blank
        end

        def address_for(attrs)
          BetterTogether::Address.find_by(attrs.slice(*ADDRESS_MATCH_FIELDS)) ||
            BetterTogether::Address.new(attrs.merge('physical' => true, 'postal' => false, 'privacy' => 'public'))
        end

        def locatable_map_url
          BetterTogether::Engine.routes.url_helpers.polymorphic_path(self, locale: I18n.locale)
        rescue NoMethodError
          Rails.application.routes.url_helpers.polymorphic_path(self, locale: I18n.locale)
        end
      end
    end
  end
end
