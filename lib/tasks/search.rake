# frozen_string_literal: true

namespace :better_together do # rubocop:todo Metrics/BlockLength
  namespace :search do # rubocop:todo Metrics/BlockLength
    require 'json'

    def search_backend
      BetterTogether::Search.backend
    end

    def registry_entries
      BetterTogether::Search::Registry.entries
    end

    def print_unmanaged_models_warning
      unmanaged = BetterTogether::Search::Registry.unmanaged_searchable_models
      return if unmanaged.empty?

      puts "WARNING: Searchable models not in registry: #{unmanaged.map(&:name).sort.join(', ')}"
    end

    def recreate_index_for(entry)
      puts "Recreating #{entry.model_name} index..."
      search_backend.delete_index(entry)
      search_backend.ensure_index(entry)
      search_backend.import_model(entry, force: true)
      search_backend.refresh_index(entry)
      puts "✓ Reindexed #{entry.db_count} #{entry.model_class.model_name.human(count: 2).downcase}"
    end

    desc 'Reindex all indexed models in the configured search backend'
    task reindex_all: :environment do
      puts "Reindexing indexed models with #{search_backend.backend_key}..."
      print_unmanaged_models_warning

      registry_entries.each do |entry|
        puts "Reindexing #{entry.model_name}..."
        search_backend.ensure_index(entry)
        search_backend.import_model(entry, force: true)
        search_backend.refresh_index(entry)
        puts "✓ Reindexed #{entry.db_count} #{entry.model_class.model_name.human(count: 2).downcase}"
      end

      puts 'Reindexing complete!'
    end

    desc 'Reindex Pages with their template blocks and rich text blocks'
    task reindex_pages: :environment do
      puts 'Reindexing Pages with template blocks and rich text blocks...'
      page_entry = BetterTogether::Search::Registry.entries.find do |entry|
        entry.model_name == 'BetterTogether::Page'
      end
      search_backend.ensure_index(page_entry)
      search_backend.import_model(page_entry, force: true)
      puts "✓ Reindexed #{BetterTogether::Page.count} pages"
    end

    desc 'Refresh indexed models in the configured search backend'
    task refresh: :environment do
      puts 'Refreshing search indices...'
      registry_entries.each { |entry| search_backend.refresh_index(entry) }
      puts '✓ Search indices refreshed'
    end

    desc 'Delete and recreate indexed models in the configured search backend'
    task recreate_indices: :environment do
      puts 'WARNING: This will delete all existing search indices and recreate them.'
      puts 'Press Ctrl+C to cancel, or Enter to continue...'
      $stdin.gets

      print_unmanaged_models_warning
      registry_entries.each { |entry| recreate_index_for(entry) }

      puts 'Search index recreation complete!'
    end

    desc 'Audit indexed models for DB-to-index parity'
    task audit: :environment do
      audit = BetterTogether::Search::AuditService.new.call

      if ENV['FORMAT'].to_s.casecmp('json').zero?
        puts JSON.pretty_generate(audit.as_json)
      else
        puts "Search backend: #{audit.backend}"
        puts "Status: #{audit.status}"
        puts "Generated at: #{audit.generated_at.iso8601}"
        print_unmanaged_models_warning

        audit.entries.each do |entry|
          puts [
            entry.model_name,
            "status=#{entry.status}",
            "db=#{entry.db_count}",
            "index=#{entry.document_count}",
            "drift=#{entry.drift_count}",
            "exists=#{entry.index_exists}"
          ].join(' | ')
        end
      end
    end
  end
end
