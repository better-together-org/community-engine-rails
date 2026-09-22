# frozen_string_literal: true

module BetterTogether
  # Resolves whether a media response is safe for shared caching.
  class MediaCachePolicy
    PUBLIC_SCOPE = 'public'
    PRIVATE_SCOPE = 'private'
    PRIVATE_CACHE_CONTROL = 'private, no-store'

    def self.for_blob(blob)
      new(blob:)
    end

    def self.for_upload(upload)
      new(upload:)
    end

    def initialize(blob: nil, upload: nil)
      @blob = blob
      @upload = upload
    end

    def cache_scope
      public? ? PUBLIC_SCOPE : PRIVATE_SCOPE
    end

    def public?
      if upload.present?
        upload.privacy_public? && upload.file_content_security_downloadable?
      elsif blob.present?
        BetterTogether::ContentSecurity::BlobAccessPolicy.public_proxy_allowed?(blob)
      else
        false
      end
    end

    def private_cache_control?
      !public?
    end

    private

    attr_reader :blob, :upload
  end
end
