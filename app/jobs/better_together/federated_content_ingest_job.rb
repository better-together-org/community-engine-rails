# frozen_string_literal: true

module BetterTogether
  class FederatedContentIngestJob < ApplicationJob
    queue_as :default

    def perform(platform_connection_id:, items:)
      connection = ::BetterTogether::PlatformConnection.find(platform_connection_id)

      ::BetterTogether::Content::FederatedContentIngestService.call(
        connection:,
        items:
      )
    end
  end
end
