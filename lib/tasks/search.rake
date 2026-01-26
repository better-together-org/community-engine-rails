# frozen_string_literal: true

namespace :better_together do # rubocop:todo Metrics/BlockLength
  namespace :search do # rubocop:todo Metrics/BlockLength
    desc 'Reindex all searchable models in Elasticsearch'
    task reindex_all: :environment do
      puts 'Reindexing all searchable models...'

      # Reindex Pages (includes template blocks and rich text blocks)
      puts 'Reindexing Pages...'
      BetterTogether::Page.elastic_import(force: true)
      puts "✓ Reindexed #{BetterTogether::Page.count} pages"

      # Add other searchable models here as needed
      # BetterTogether::OtherModel.elastic_import(force: true)

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
