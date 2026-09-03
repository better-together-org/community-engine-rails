# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pushes the outcome of an async checkout-session sync (SyncCheckoutSessionJob)
    # to the billing page via Turbo Streams, replacing the pending/spinner
    # region rendered by _checkout_session_pending.html.erb. The stream is
    # keyed on checkout_session_id (narrower than owner-based) so a page
    # reload with a different session ID never receives a stale broadcast
    # meant for an earlier one. Message-building here mirrors what
    # Billing::ControllerConcern#sync_checkout_session and
    # CommunityBillingsController#process_sponsorship_contribution used to do
    # inline via flash.now — I18n.t instead of the controller's t(), since
    # this runs outside a request.
    class CheckoutSessionSyncBroadcaster
      def self.stream_name(checkout_session_id)
        "checkout_session_#{checkout_session_id}"
      end

      def self.target_dom_id(checkout_session_id)
        "checkout-session-sync-#{checkout_session_id}"
      end

      def call(checkout_session_id:, result: nil, error: nil)
        contribution_result = contribution_processor.call(result)

        Turbo::StreamsChannel.broadcast_replace_to(
          self.class.stream_name(checkout_session_id),
          target: self.class.target_dom_id(checkout_session_id),
          partial: 'better_together/shared/checkout_session_result',
          locals: {
            dom_id: self.class.target_dom_id(checkout_session_id),
            messages: [sync_message(result:, error:), contribution_message(contribution_result)].compact
          }
        )
      end

      private

      def contribution_processor
        @contribution_processor ||= BetterTogether::Billing::ProcessSponsorshipContributionFromCheckoutSync.new
      end

      def sync_message(result:, error:)
        return { variant: :alert, text: checkout_session_invalid_message(error) } if error

        {
          variant: result&.synced ? :notice : :alert,
          text: sync_message_text(result)
        }
      end

      def sync_message_text(result)
        return checkout_sync_complete_message if result&.synced
        if result&.reason.in?(%i[beneficiary_mismatch billable_owner_mismatch ownership_mismatch])
          return checkout_sync_wrong_beneficiary_message
        end

        checkout_sync_pending_message
      end

      def contribution_message(contribution_result)
        return if contribution_result.blank? || contribution_result.already_credited

        if contribution_result.error
          { variant: :alert, text: sponsorship_contribution_failed_message(contribution_result.error) }
        elsif contribution_result.credited
          { variant: :notice, text: sponsorship_contribution_complete_message(contribution_result.beneficiary) }
        end
      end

      def checkout_session_invalid_message(error)
        I18n.t(
          'better_together.billing.checkout_session_invalid',
          default: 'The Stripe checkout session could not be synchronized: %<message>s',
          message: ERB::Util.html_escape(error.message)
        )
      end

      def checkout_sync_complete_message
        I18n.t('better_together.billing.checkout_sync_complete', default: 'Stripe checkout was synchronized successfully.')
      end

      def checkout_sync_wrong_beneficiary_message
        I18n.t(
          'better_together.billing.checkout_sync_wrong_beneficiary',
          default: 'This Stripe checkout session does not belong to this billing page.'
        )
      end

      def checkout_sync_pending_message
        I18n.t(
          'better_together.billing.checkout_sync_pending',
          default: 'Stripe checkout was received, but no subscription state could be synchronized yet.'
        )
      end

      def sponsorship_contribution_complete_message(beneficiary)
        I18n.t(
          'better_together.billing.sponsorship_contribution_complete',
          default: 'Your contribution to %<beneficiary>s was recorded.',
          beneficiary: beneficiary.name
        )
      end

      def sponsorship_contribution_failed_message(error)
        I18n.t(
          'better_together.billing.sponsorship_contribution_failed',
          default: 'Your payment succeeded, but recording the contribution failed: %<message>s',
          message: ERB::Util.html_escape(error.message)
        )
      end
    end
  end
end
