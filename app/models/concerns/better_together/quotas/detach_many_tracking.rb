# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Prepended onto ActiveStorage::Attached::Changes::DetachMany (config/
    # initializers/quotas.rb). has_many_attached #detach deletes its attachments
    # with a single relation delete_all, so neither Attachment#delete nor any
    # callback runs; this reverses each one once the delete has gone through.
    module DetachManyTracking
      def detach
        detached = attachments.to_a
        super.tap do
          detached.each(&:reverse_media_storage_quota)
        end
      end
    end
  end
end
