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

          accepts_nested_attributes_for :location,
                                        allow_destroy: true, reject_if: :blank?
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
