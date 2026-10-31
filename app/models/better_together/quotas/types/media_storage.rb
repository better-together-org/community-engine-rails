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

        # Provisional defaults (product decision pending, not an engineering one):
        # a large bigint-safe stand-in for "unlimited" is used for owner kinds (e.g.
        # Platform) that are not meant to be capped in this phase.
        UNLIMITED = 10**15
        PERSON_DEFAULT_BYTES = 5 * (1024**3)
        COMMUNITY_DEFAULT_BYTES = 25 * (1024**3)

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

          def default_limit(owner)
            case owner
            when BetterTogether::Person then PERSON_DEFAULT_BYTES
            when BetterTogether::Community then COMMUNITY_DEFAULT_BYTES
            else UNLIMITED
            end
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
