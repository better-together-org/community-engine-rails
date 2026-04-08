# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    module ActiveStorage
      module Blobs
        # Shared proxy gate for CE-generated blob URLs.
        class ProxyController < ::ActiveStorage::Blobs::ProxyController
          before_action :enforce_content_security!

          private

          def enforce_content_security!
            head :not_found unless BetterTogether::ContentSecurity::BlobAccessPolicy.public_proxy_allowed?(@blob)
          end
        end
      end
    end
  end
end
