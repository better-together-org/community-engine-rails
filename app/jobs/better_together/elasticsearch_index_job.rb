
module BetterTogether
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
