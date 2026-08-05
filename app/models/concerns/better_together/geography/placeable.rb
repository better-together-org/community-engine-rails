# frozen_string_literal: true

module BetterTogether
  module Geography
    # Dynamic extension point (see docs/developers/architecture/
    # polymorphic_allowlist_extension_audit.md): marks a model as a valid target for
    # LocatableLocation#location, discovered via .included_in_models instead of a hardcoded
    # allow-list. Include this in any model that a locatable (Event, etc.) can be located at.
    module Placeable
      extend ActiveSupport::Concern

      def self.included_in_models
        included_module = self
        Rails.application.eager_load! unless Rails.env.production?
        ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
      end

      class_methods do
        # Default: lookup-only (never build a new record from nested attrs). Address/Building
        # override this to support inline creation of a new nested record; Settlement/Region
        # rely on this default and are therefore never created via a locatable_location form —
        # always picked from the existing curated set.
        def locatable_location_build(attrs)
          find_by(id: attrs['id'] || attrs['location_id'])
        end

        # Path to the partial rendering this model's inline "+New" nested-attributes
        # fields in the event location picker, or nil if lookup-only (the default —
        # matches locatable_location_build's default "never build" behavior).
        # Address/Building override this to opt into inline creation.
        def inline_create_fields_partial
          nil
        end

        def inline_creatable?
          inline_create_fields_partial.present?
        end
      end
    end
  end
end
