# frozen_string_literal: true

module BetterTogether
  # Declares standard Turbo Stream broadcasts for a model, always via the async
  # (job-queued) `_later` variants.
  #
  # broadcast_append_to's synchronous variant renders via the host app's bare
  # ApplicationController.render (Rails engines don't get their own render context
  # here), which has none of this engine's helpers/Pundit mixed in — current_user,
  # current_person, and policy() all raise or silently misbehave there. Comment and
  # Message each solved this independently by reaching for the `_later` variant and
  # documenting the reason inline; this concern centralizes both the fix and the
  # rationale so a future broadcastable model gets it from a single include instead
  # of copy-pasting the workaround again.
  module Broadcastable
    extend ActiveSupport::Concern

    class_methods do
      # stream: name of the association/method returning the streamable object
      #   broadcasts are sent to, e.g. :commentable or :conversation.
      # target: the DOM id new content is appended to — a literal string, or the name
      #   of a method (called on the instance) for a dynamic id like
      #   comments_stream_target.
      # on_destroy: also broadcast a removal from `stream` when the record is destroyed
      #   (Turbo passes render: false for removals, so there's no template/context
      #   problem there — no `_later` needed for that half).
      def broadcasts_async_to(stream, target:, on_destroy: false)
        after_create_commit(lambda {
          resolved_target = target.is_a?(Symbol) ? send(target) : target
          broadcast_append_later_to send(stream), target: resolved_target
        })

        return unless on_destroy

        after_destroy_commit(-> { broadcast_remove_to send(stream) })
      end
    end
  end
end
