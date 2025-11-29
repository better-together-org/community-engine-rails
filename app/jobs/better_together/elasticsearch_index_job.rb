# frozen_string_literal: true

module BetterTogether
  # Queues up Elasticsearch indexing jobs in the background
  # This job is responsible for indexing and deleting documents in Elasticsearch
  # when records are created, updated, or destroyed.
  class ElasticsearchIndexJob < ApplicationJob
    queue_as :es_indexing

    # Don't retry on deserialization errors - the record no longer exists
    discard_on ActiveJob::DeserializationError

    def perform(record, action)
      return unless record.respond_to? :__elasticsearch__

      execute_elasticsearch_action(record, action)
    rescue ActiveRecord::RecordNotFound
      # Record was deleted before the job could run - this is expected for delete operations
      Rails.logger.info "ElasticsearchIndexJob: Record no longer exists, skipping #{action} operation"
    end

    private

    def execute_elasticsearch_action(record, action)
      case action
      when :index
        record.__elasticsearch__.index_document
      when :delete
        record.__elasticsearch__.delete_document
      else
        raise ArgumentError, "Unknown action: #{action}"
      end
    end
  end
end
