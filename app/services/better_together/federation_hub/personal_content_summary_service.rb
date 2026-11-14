# frozen_string_literal: true

module BetterTogether
  module FederationHub
    # Summarizes a person's own content federation status for the Federation
    # Hub's personal panel: their federate_content preference, counts of their
    # content by federation_visibility, and their most recently touched items.
    class PersonalContentSummaryService
      RECENT_ITEMS_LIMIT = 5

      def self.call(person:)
        new(person:).call
      end

      def initialize(person:)
        @person = person
      end

      def call
        {
          federate_content: person&.federate_content?,
          counts_by_visibility: counts_by_visibility,
          recent_items: recent_items
        }
      end

      private

      attr_reader :person

      # Discovers content classes dynamically via Federatable.included_in_models
      # instead of a hardcoded allowlist, so any future federatable model is
      # picked up automatically. Scoped to classes with a creator_id column,
      # since system-owned federatable records (creator_id nil) have nothing
      # to attribute to a person here.
      def federatable_content_classes
        ::BetterTogether::Federatable.included_in_models.select do |klass|
          klass.column_names.include?('creator_id')
        end
      end

      def counts_by_visibility
        return {} unless person

        federatable_content_classes.each_with_object(Hash.new(0)) do |klass, totals|
          klass.where(creator_id: person.id).group(:federation_visibility).count.each do |visibility, count|
            totals[visibility] += count
          end
        end
      end

      def recent_items
        return [] unless person

        federatable_content_classes
          .flat_map { |klass| klass.where(creator_id: person.id).order(updated_at: :desc).limit(RECENT_ITEMS_LIMIT) }
          .sort_by(&:updated_at)
          .reverse
          .first(RECENT_ITEMS_LIMIT)
      end
    end
  end
end
