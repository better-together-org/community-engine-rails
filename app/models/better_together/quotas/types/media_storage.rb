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

        # Sized against real shadow-mode usage across 4 production apps (heaviest
        # real owner anywhere: ~37MB), with generous headroom, but bounded against
        # S3/Garage storage cost rather than left arbitrarily large. Platform gets
        # a real finite ceiling instead of a number too large for the cost framing
        # to mean anything, while staying far above any real platform-level total
        # observed (so it is still, in practice, never hit organically).
        PLATFORM_DEFAULT_BYTES = 1024 * (1024**3) # 1 TiB
        PERSON_DEFAULT_BYTES = 2 * (1024**3) # 2 GiB
        COMMUNITY_DEFAULT_BYTES = 10 * (1024**3) # 10 GiB

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
            else PLATFORM_DEFAULT_BYTES
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
