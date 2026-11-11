# frozen_string_literal: true

module BetterTogether
  module Quotas
    module Types
      # Bytes consumed by any ActiveStorage attachment anywhere in the engine or a
      # host app. measure/counts_toward_quota? are deliberately subject-class-agnostic
      # the global ActiveStorage::Attachment hook (Quotas::AttachmentTracking)
      # already covers every attachment path, so this type never branches per model.
      class MediaStorage < BetterTogether::Quotas::Type
        KEY = 'media_storage'

        class << self
          def key
            KEY
          end

          def unit
            :bytes
          end

          def period
            'cumulative'
          end

          # A purged/detached attachment genuinely frees local storage.
          def reversible?
            true
          end

          def measure(subject)
            subject.blob.byte_size
          end
        end
      end
    end
  end
end

BetterTogether::Quotas::Type.register(
  BetterTogether::Quotas::Types::MediaStorage.key,
  BetterTogether::Quotas::Types::MediaStorage
)
