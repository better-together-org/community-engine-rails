# frozen_string_literal: true

module BetterTogether
  class ElasticsearchIndexJob < ApplicationJob
    queue_as :es_indexing

    discard_on ActiveJob::DeserializationError

    def perform(record, action)
      execute_elasticsearch_action(record, action)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.info "ElasticsearchIndexJob: Record no longer exists, skipping #{action} operation"
    end

    private

    def execute_elasticsearch_action(record, action)
      case action
      when :index
        BetterTogether::Search.backend.index_record(record)
      when :delete
        BetterTogether::Search.backend.delete_record(record)
      else
        raise ArgumentError, "Unknown action: #{action}"
      end
    end
  end
end
