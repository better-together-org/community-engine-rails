# frozen_string_literal: true

module BetterTogether
  module Geography
    module Locatable
      # Configures locatables that can be placed into the geography hierarchy
      # (Settlement/Region/State/Country/Continent) via multiple LocatableLocation rows,
      # one per hierarchy level, resolved automatically by HierarchyResolutionJob based on
      # PostGIS polygon containment. Distinct from Locatable::One, which gives a locatable a
      # single primary location (e.g. an Event's address/building/settlement pick).
      module Many
        extend ActiveSupport::Concern

        included do
          has_many :locatable_locations,
                   class_name: 'BetterTogether::Geography::LocatableLocation',
                   as: :locatable,
                   dependent: :destroy
        end

        # Dynamic extension point (see docs/developers/architecture/
        # polymorphic_allowlist_extension_audit.md): reflects on which models actually
        # include this concern instead of maintaining a hardcoded class list.
        def self.included_in_models
          included_module = self
          Rails.application.eager_load! unless Rails.env.production?
          ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
        end

        %i[settlement region state country continent].each do |level|
          define_method(level) do
            locatable_locations.find_by(location_type: "BetterTogether::Geography::#{level.to_s.camelize}")&.location
          end
        end

        def resolve_geographic_hierarchy!(async: true)
          if async
            BetterTogether::Geography::HierarchyResolutionJob.perform_later(self)
          else
            BetterTogether::Geography::HierarchyResolutionJob.perform_now(self)
          end
        end
      end
    end
  end
end
