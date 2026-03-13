# frozen_string_literal: true

namespace :better_together do # rubocop:todo Metrics/BlockLength
  namespace :search do # rubocop:todo Metrics/BlockLength
    def reindex_searchable_model(model)
      puts "Reindexing #{model.name}..."
      model.elastic_import(force: true)
      puts "✓ Reindexed #{model.count} #{model.model_name.human(count: 2).downcase}"
    end

    def searchable_models_for_reindex(all_models:)
      return [BetterTogether::Page] unless all_models

      Rails.application.eager_load!

      BetterTogether::Searchable.included_in_models
                                .select { |model| model.respond_to?(:elastic_import) }
                                .sort_by(&:name)
    end

    desc 'Reindex all searchable models in Elasticsearch'
    task reindex_all: :environment do
      puts 'Reindexing all searchable models...'

      # Opt in to full model reindex with ALL_MODELS=true.
      # Default behavior remains page-only for backward compatibility.
      all_models = ENV['ALL_MODELS'].to_s.downcase == 'true'
      models = searchable_models_for_reindex(all_models:)

      models.each { |model| reindex_searchable_model(model) }

      puts 'Reindexing complete!'
    end

    desc 'Reindex Pages with their template blocks and rich text blocks'
    task reindex_pages: :environment do
      puts 'Reindexing Pages with template blocks and rich text blocks...'
      BetterTogether::Page.elastic_import(force: true)
      puts "✓ Reindexed #{BetterTogether::Page.count} pages"
    end

    desc 'Refresh Elasticsearch indices'
    task refresh: :environment do
      puts 'Refreshing Elasticsearch indices...'
      BetterTogether::Page.refresh_elastic_index!
      puts '✓ Indices refreshed'
    end

    desc 'Delete and recreate Elasticsearch indices'
    task recreate_indices: :environment do
      puts 'WARNING: This will delete all existing search indices and recreate them.'
      puts 'Press Ctrl+C to cancel, or Enter to continue...'
      $stdin.gets

      puts 'Deleting existing indices...'
      BetterTogether::Page.delete_elastic_index!
      puts '✓ Indices deleted'

      puts 'Creating new indices...'
      BetterTogether::Page.create_elastic_index!
      puts '✓ Indices created'

      puts 'Reindexing all data...'
      BetterTogether::Page.elastic_import(force: true)
      puts "✓ Reindexed #{BetterTogether::Page.count} pages"

      puts 'Index recreation complete!'
    end
  end
end
