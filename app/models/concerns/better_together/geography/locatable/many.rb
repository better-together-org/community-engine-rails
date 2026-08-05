# frozen_string_literal: true

module BetterTogether
  module Geography
    module Locatable
      # Configures locatables that can be placed into the geography hierarchy
      # (Settlement/Region/State/Country/Continent) via multiple LocatableLocation rows,
      # one per hierarchy level, resolved automatically by HierarchyResolutionJob based on
      # PostGIS polygon containment. Distinct from Locatable::One, which gives a locatable a
      # single primary location (e.g. an Event's address/building/settlement pick).
      #
      # Only include this in models that actually get their OWN Space geocoded (Address,
      # Building — both have an active `geocoded_by`). Event does NOT belong here even
      # though it also self-geocodes (see Geospatial::One.geocodes_self) — its geography
      # placement is reached through its Locatable::One location instead (e.g.
      # `event.location.location.settlement` when that location is an Address), not by
      # resolving its own Space against these hierarchy polygons.
      module Many
        extend ActiveSupport::Concern

        # Canonical hierarchy level => class mapping. Single source of truth for which
        # levels HierarchyResolutionJob resolves and how the reader methods below look up
        # their placement — avoids three independent `level.to_s.camelize.constantize`
        # call sites (previously duplicated across this concern, HierarchyResolutionJob's
        # polygon/iso_code/name-similarity resolvers, and its upsert helper) silently
        # drifting out of sync.
        LEVELS = {
          settlement: BetterTogether::Geography::Settlement,
          region: BetterTogether::Geography::Region,
          state: BetterTogether::Geography::State,
          country: BetterTogether::Geography::Country,
          continent: BetterTogether::Geography::Continent
        }.freeze

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

        # .to_a (rather than .find_by) loads and memoizes locatable_locations on first
        # call, so calling multiple level accessors on one record costs at most one
        # query instead of one per accessor — and callers that preload the association
        # (e.g. .includes(:locatable_locations)) get the full benefit for free.
        LEVELS.each do |level, klass|
          define_method(level) { locatable_locations.to_a.find { |ll| ll.location_type == klass.name }&.location }
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
