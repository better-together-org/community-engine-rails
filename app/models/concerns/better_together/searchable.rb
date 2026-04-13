# frozen_string_literal: true

# app/models/concerns/searchable.rb

module BetterTogether
  # Shared model-side search contract for all backend implementations.
  module Searchable
    extend ActiveSupport::Concern

    included do
      include PgSearch::Model

      class_attribute :search_global_search_enabled, instance_writer: false, default: true
      class_attribute :search_scope_name, instance_writer: false, default: nil
      class_attribute :search_pg_search_options, instance_writer: false, default: nil
    end

    # Class-level helpers for searchable models.
    module ClassMethods
      def searchable(scope_name: :pg_search_query, global_search: true, pg_search: nil)
        normalized_pg_search = normalize_pg_search_options(pg_search)

        self.search_global_search_enabled = global_search
        self.search_scope_name = normalized_pg_search.present? ? scope_name : nil
        self.search_pg_search_options = normalized_pg_search&.deep_dup

        pg_search_scope(scope_name, **normalized_pg_search) if normalized_pg_search.present?
      end

      def indexed_models
        BetterTogether::Search::Registry.models
      end

      def unmanaged_models
        included_in_models - indexed_models
      end

      def global_searchable?
        search_global_search_enabled
      end

      def search_relation
        all
      end

      def pg_search_enabled?
        search_pg_search_options.present? && search_scope_name.present?
      end

      def search_backend_query(query)
        return search_relation unless pg_search_enabled?

        public_send(search_scope_name, query)
      end

      def search_registry_entry
        BetterTogether::Search::Registry::Entry.new(
          model_name: name,
          global_search: global_searchable?
        )
      end
      private

      def normalize_pg_search_options(pg_search)
        return if pg_search.blank?

        pg_search.deep_dup.tap do |options|
          options[:associated_against] = merge_pg_search_associations(
            default_pg_search_associations,
            options[:associated_against] || {}
          )
        end
      end

      def default_pg_search_associations
        {}.tap do |associations|
          associations[:string_translations] = [:value] if reflect_on_association(:string_translations)
          associations[:text_translations] = [:value] if reflect_on_association(:text_translations)
          associations[:rich_text_translations] = [:body] if reflect_on_association(:rich_text_translations)
        end
      end

      def merge_pg_search_associations(defaults, overrides)
        defaults.deep_merge(overrides) do |_key, default_value, override_value|
          if default_value.is_a?(Array) && override_value.is_a?(Array)
            (default_value + override_value).uniq
          else
            override_value
          end
        end
      end
    end

    def self.included_in_models
      Rails.application.eager_load! unless Rails.env.production? # Ensure all models are loaded
      ActiveRecord::Base.descendants.select { |model| model.include?(BetterTogether::Searchable) }
    end
  end
end
