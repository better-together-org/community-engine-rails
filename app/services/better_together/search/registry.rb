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

        def relation
          model_class.all
        end

        def db_count
          relation.count
        end
      end

      ENTRIES = [
        Entry.new(model_name: 'BetterTogether::Page', global_search: true),
        Entry.new(model_name: 'BetterTogether::Post', global_search: true)
      ].freeze

      module_function

      def entries
        ENTRIES
      end

      def models
        entries.map(&:model_class)
      end

      def global_search_models
        entries.select(&:global_search).map(&:model_class)
      end

      def unmanaged_searchable_models
        BetterTogether::Searchable.included_in_models - models
      end
    end
  end
end
