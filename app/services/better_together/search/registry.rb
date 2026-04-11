# frozen_string_literal: true

module BetterTogether
  module Search
    # Source of truth for models that are fully wired for backend indexing/search.
    module Registry
      # Metadata for a searchable model.
      Entry = Struct.new(:model_name, :global_search) do
        def model_class
          model_name.constantize
        end

        def index_name
          model_class.__elasticsearch__.index_name
        end

        def search_scope_name
          model_class.search_scope_name
        end

        def relation
          model_class.search_relation
        end

        def db_count
          relation.count
        end

        def search_relation(query)
          model_class.search_backend_query(query)
        end

        def pg_search_enabled?
          model_class.pg_search_enabled?
        end
      end

      module_function

      def entries
        searchable_models = BetterTogether::Searchable.included_in_models.select do |model|
          model.respond_to?(:search_registry_entry) && model.base_class == model
        end

        searchable_models.map(&:search_registry_entry).sort_by(&:model_name)
      end

      def models
        entries.map(&:model_class)
      end

      def global_search_models
        entries.select(&:global_search).map(&:model_class)
      end

      def unmanaged_searchable_models
        BetterTogether::Searchable.included_in_models.reject { |model| model.respond_to?(:search_registry_entry) }
      end
    end
  end
end
