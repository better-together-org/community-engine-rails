# frozen_string_literal: true

module BetterTogether
  # Queues up Elasticsearch indexing jobs in the background
  # This job is responsible for indexing and deleting documents in Elasticsearch
  # when records are created, updated, or destroyed.
  class ElasticsearchIndexJob < ApplicationJob
    queue_as :default

    def perform(record, action)
      return unless record.respond_to? :__elasticsearch__

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
