# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Background job to clean up orphaned RichTextLink records
    # Removes links where the associated record has been deleted
    class OrphanedRichTextLinkCleanupJob < MetricsJob
      queue_as :maintenance

      def perform
        total_cleaned = 0

        # Get all distinct record types from ActionText::RichText that have associated RichTextLinks
        # Using Arel to build the join query
        rich_texts = ActionText::RichText.arel_table
        rich_text_links = BetterTogether::Metrics::RichTextLink.arel_table

        record_types = ActionText::RichText
                       .joins(rich_texts.join(rich_text_links)
                                .on(rich_texts[:id].eq(rich_text_links[:rich_text_id]))
                                .join_sources)
                       .distinct
                       .pluck(:record_type)

        record_types.each do |record_type|
          cleaned_count = cleanup_orphaned_links_for_type(record_type)
          total_cleaned += cleaned_count
        end

        Rails.logger.info "Orphaned link cleanup completed. Total links cleaned up: #{total_cleaned}"
      end

      private

      def cleanup_orphaned_links_for_type(record_type)
        model_class = record_type.constantize
        orphaned_ids = find_orphaned_rich_text_ids(record_type, model_class)
        delete_orphaned_links(orphaned_ids, record_type)
      rescue NameError => e
        handle_missing_model_class(record_type, e)
      end

      def find_orphaned_rich_text_ids(record_type, model_class)
        rich_text_ids = ActionText::RichText.where(record_type: record_type).pluck(:id)
        orphaned_ids = []

        ActionText::RichText.where(id: rich_text_ids).find_each do |rich_text|
          orphaned_ids << rich_text.id unless model_class.exists?(rich_text.record_id)
        end

        orphaned_ids
      end

      def delete_orphaned_links(orphaned_ids, record_type)
        return 0 if orphaned_ids.empty?

        count = BetterTogether::Metrics::RichTextLink
                .where(rich_text_id: orphaned_ids)
                .delete_all

        Rails.logger.info "Cleaned up #{count} orphaned links for #{record_type}"
        count
      end

      def handle_missing_model_class(record_type, error)
        Rails.logger.warn "Model class #{record_type} does not exist. " \
                          "Removing all associated links. Error: #{error.message}"

        rich_text_ids = ActionText::RichText.where(record_type: record_type).pluck(:id)
        count = BetterTogether::Metrics::RichTextLink
                .where(rich_text_id: rich_text_ids)
                .delete_all

        Rails.logger.info "Cleaned up #{count} orphaned links for non-existent model #{record_type}"
        count
      end
    end
  end
end
