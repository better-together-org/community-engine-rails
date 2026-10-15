# frozen_string_literal: true

module BetterTogether
  module Geography
    # Dynamic extension point (see docs/developers/architecture/
    # polymorphic_allowlist_extension_audit.md): marks a model as a valid target for
    # LocatableLocation#location, discovered via .included_in_models instead of a hardcoded
    # allow-list. Include this in any model that a locatable (Event, etc.) can be located at.
    module Placeable
      extend ActiveSupport::Concern

      # Matches HierarchyResolutionJob::STATE_NAME_SIMILARITY_THRESHOLD's rationale:
      # favor avoiding false positives over catching every minor spelling variant.
      NAME_SIMILARITY_THRESHOLD = 0.2

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

        # Trigram-similarity search against this model's Mobility-translated `name`
        # attribute, reusing the same mobility_string_translations GIN trigram index
        # and Arel similarity() pattern as HierarchyResolutionJob#name_similarity_function
        # (the two live in different domains - job-scoped State resolution vs. the event
        # location picker - so aren't merged into one method, but share the same query
        # shape deliberately). Only meaningful for models with `translates :name`
        # (Building, Floor, Room, Settlement, Region); Address has no single translated
        # name field and implements its own search filtering instead.
        def name_similarity_scope(search)
          return all if search.blank?

          translations = Arel::Table.new(:mobility_string_translations)
          similarity = Arel::Nodes::NamedFunction.new('similarity', [translations[:value], Arel::Nodes.build_quoted(search)])

          joins(name_translations_join)
            .where(similarity.gt(NAME_SIMILARITY_THRESHOLD))
            .order(similarity.desc)
        end

        def name_translations_join # rubocop:todo Metrics/AbcSize
          translations = Arel::Table.new(:mobility_string_translations)

          arel_table.join(translations)
                    .on(translations[:translatable_type].eq(base_class.name)
                          .and(translations[:translatable_id].eq(arel_table[:id]))
                          .and(translations[:key].eq('name')))
                    .join_sources
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
