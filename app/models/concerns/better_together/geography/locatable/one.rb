# frozen_string_literal: true

module BetterTogether
  module Geography
    module Locatable
      # Configures locatables with one location
      module One
        extend ActiveSupport::Concern

        included do
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
      end
    end
  end
end
