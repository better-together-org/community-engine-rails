# frozen_string_literal: true

# Mobility Title Translation Migration Tasks
#
# These tasks handle migrating title translations from the mobility_text_translations
# table to the mobility_string_translations table. This fixes an issue where titles
# were incorrectly stored as text type instead of string type due to missing type
# declarations in translates calls.
#
# Affected Models:
# - BetterTogether::Post
# - BetterTogether::Agreement
# - BetterTogether::Geography::Map
#
# Performance Optimizations:
# - Uses bulk operations (insert_all, delete_all) instead of individual record operations
# - Reduces database round trips from N operations to 2 operations
# - Bypasses ActiveRecord callbacks (especially Elasticsearch indexing)
# - Provides timing information for performance monitoring
#
# Usage:
#   bin/dc-run rails translations:mobility:check_titles_status          # Check current status
#   bin/dc-run rails translations:mobility:migrate_titles_to_string     # Perform migration
#   bin/dc-run rails translations:mobility:clean_up_title_translations  # Clean up remaining records
#
# The migration can also be executed through Rails migrations via:
#   bin/dc-run rails db:migrate

namespace :translations do
  namespace :mobility do
    desc 'Migrate title translations from text to string translations'
    task migrate_titles_to_string: :environment do # rubocop:todo Metrics/BlockLength
      puts 'Starting migration of titles from text to string translations...'
      puts '=' * 80

      # Use Mobility's KeyValue backend models for safer operations
      text_translation_class = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
      string_translation_class = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation

      # Find all title translations in text translations
      text_title_translations = text_translation_class.where(key: 'title')

      puts "Found #{text_title_translations.count} title translations in text_translations table"

      if text_title_translations.empty?
        puts 'No title translations found in text translations table. Migration not needed.'
        next
      end

      # Group by translatable_type for reporting
      grouped_translations = text_title_translations.group_by(&:translatable_type)
      grouped_translations.each do |type, translations|
        puts "  - #{type}: #{translations.count} translations"
      end

      puts "\nStarting migration process..."
      puts '-' * 40

      migration_count = 0
      skipped_count = 0
      error_count = 0

      # Collect records for bulk operations
      records_to_create = []
      records_to_delete = []

      text_title_translations.each_with_index do |text_translation, index|
        begin
          # Check if a string translation already exists for this record
          existing_string = string_translation_class.find_by(
            translatable_type: text_translation.translatable_type,
            translatable_id: text_translation.translatable_id,
            key: 'title',
            locale: text_translation.locale
          )

          if existing_string.nil?
            # Prepare record for bulk creation
            records_to_create << {
              translatable_type: text_translation.translatable_type,
              translatable_id: text_translation.translatable_id,
              key: 'title',
              locale: text_translation.locale,
              value: text_translation.value,
              created_at: text_translation.created_at,
              updated_at: text_translation.updated_at
            }

            # rubocop:todo Layout/LineLength
            puts "✓ Prepared for migration: #{text_translation.translatable_type} ##{text_translation.translatable_id} title (#{text_translation.locale}): '#{text_translation.value}'"
            # rubocop:enable Layout/LineLength
            migration_count += 1
          else
            # rubocop:todo Layout/LineLength
            puts "⚠ String translation already exists for #{text_translation.translatable_type} ##{text_translation.translatable_id} title (#{text_translation.locale}), skipping"
            # rubocop:enable Layout/LineLength
            skipped_count += 1
          end

          # Always prepare text translation for bulk deletion
          records_to_delete << text_translation.id
        rescue StandardError => e
          # rubocop:todo Layout/LineLength
          puts "✗ Error preparing #{text_translation.translatable_type} ##{text_translation.translatable_id}: #{e.message}"
          # rubocop:enable Layout/LineLength
          error_count += 1
        end

        # Progress indicator for large datasets
        if ((index + 1) % 10).zero? || (index + 1) == text_title_translations.count
          puts "Progress: #{index + 1}/#{text_title_translations.count} prepared"
        end
      end

      # Perform bulk operations
      puts "\nPerforming bulk operations..."
      puts '-' * 40

      # Bulk create string translations
      if records_to_create.any?
        puts "Creating #{records_to_create.count} string translations in bulk..."
        start_time = Time.current
        begin
          string_translation_class.insert_all(records_to_create)
          elapsed = (Time.current - start_time).round(3)
          puts "✓ Successfully created #{records_to_create.count} string translations in #{elapsed}s"
        rescue StandardError => e
          elapsed = (Time.current - start_time).round(3)
          puts "✗ Error during bulk creation (#{elapsed}s): #{e.message}"
          error_count += records_to_create.count
          migration_count -= records_to_create.count
        end
      end

      # Bulk delete text translations
      if records_to_delete.any?
        puts "Deleting #{records_to_delete.count} text translations in bulk..."
        start_time = Time.current
        begin
          deleted_count = text_translation_class.where(id: records_to_delete).delete_all
          elapsed = (Time.current - start_time).round(3)
          puts "✓ Successfully deleted #{deleted_count} text translations in #{elapsed}s"
        rescue StandardError => e
          elapsed = (Time.current - start_time).round(3)
          puts "✗ Error during bulk deletion (#{elapsed}s): #{e.message}"
        end
      end

      puts "\n#{'=' * 80}"
      puts 'Migration Summary:'
      puts "  ✓ Successfully migrated: #{migration_count}"
      puts "  ⚠ Skipped (already exist): #{skipped_count}"
      puts "  ✗ Errors encountered: #{error_count}"
      puts "  Total processed: #{text_title_translations.count}"
      puts "\nMigration completed!"
    end

    desc 'Clean up remaining title text translations after successful migration (DANGEROUS: removes data)'
    task clean_up_title_translations: :environment do
      puts 'Cleaning up remaining text translations for titles...'
      puts '⚠️  WARNING: This will permanently delete records from the text_translations table!'
      puts '=' * 80

      text_translation_class = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
      string_translation_class = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation

      text_title_translations = text_translation_class.where(key: 'title')

      if text_title_translations.empty?
        puts '✅ No text translations found to clean up!'
        next
      end

      puts "Found #{text_title_translations.count} remaining text translations:"

      cleanup_count = 0
      verification_failures = 0
      records_to_delete = []

      text_title_translations.each do |text_translation|
        string_exists = string_translation_class.exists?(
          translatable_type: text_translation.translatable_type,
          translatable_id: text_translation.translatable_id,
          key: 'title',
          locale: text_translation.locale
        )

        if string_exists
          records_to_delete << text_translation.id
          # rubocop:todo Layout/LineLength
          puts "🗑️  Prepared for cleanup: #{text_translation.translatable_type} ##{text_translation.translatable_id} title (#{text_translation.locale})"
          # rubocop:enable Layout/LineLength
          cleanup_count += 1
        else
          # rubocop:todo Layout/LineLength
          puts "⚠️  String translation missing for #{text_translation.translatable_type} ##{text_translation.translatable_id} (#{text_translation.locale}) - skipping cleanup"
          # rubocop:enable Layout/LineLength
          verification_failures += 1
        end
      end

      if records_to_delete.any?
        puts "\nPerforming bulk cleanup of #{records_to_delete.count} records..."
        start_time = Time.current
        begin
          deleted_count = text_translation_class.where(id: records_to_delete).delete_all
          elapsed = (Time.current - start_time).round(3)
          puts "✓ Successfully cleaned up #{deleted_count} text translations in #{elapsed}s"
        rescue StandardError => e
          elapsed = (Time.current - start_time).round(3)
          puts "✗ Error during bulk cleanup (#{elapsed}s): #{e.message}"
          cleanup_count = 0
        end
      end

      puts "\n#{'=' * 80}"
      puts 'Cleanup Summary:'
      puts "  🗑️  Records cleaned up: #{cleanup_count}"
      puts "  ⚠️  Verification failures: #{verification_failures}"
      puts "  Total processed: #{text_title_translations.count}"
      puts "\nCleanup completed!"
    end

    desc 'Check status of title translations (dry run)'
    task check_titles_status: :environment do
      puts 'Checking status of title translations...'
      puts '=' * 80

      text_translation_class = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
      string_translation_class = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation

      text_title_translations = text_translation_class.where(key: 'title')
      string_title_translations = string_translation_class.where(key: 'title')

      puts 'Current Translation Status:'
      puts '-' * 40
      puts '📝 Text translations (should be 0 after migration):'
      puts "   Total: #{text_title_translations.count}"

      if text_title_translations.any?
        grouped_text = text_title_translations.group_by(&:translatable_type)
        grouped_text.each do |type, translations|
          puts "   - #{type}: #{translations.count}"
          translations.first(3).each do |trans|
            puts "     • ID #{trans.translatable_id} (#{trans.locale}): '#{trans.value}'"
          end
          puts "     ... and #{translations.count - 3} more" if translations.count > 3
        end
      end

      puts "\n📄 String translations (target location):"
      puts "   Total: #{string_title_translations.count}"

      if string_title_translations.any?
        grouped_string = string_title_translations.group_by(&:translatable_type)
        grouped_string.each do |type, translations|
          puts "   - #{type}: #{translations.count}"
          translations.first(3).each do |trans|
            puts "     • ID #{trans.translatable_id} (#{trans.locale}): '#{trans.value}'"
          end
          puts "     ... and #{translations.count - 3} more" if translations.count > 3
        end
      end

      puts "\n#{'=' * 80}"
      if text_title_translations.empty?
        puts '✅ Migration appears complete - no title translations found in text_translations'
      else
        puts "⚠️  Migration needed - #{text_title_translations.count} title translations found in text_translations"
        puts '   Run: rails translations:mobility:migrate_titles_to_string'
      end
    end
  end
end
