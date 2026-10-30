# frozen_string_literal: true

module BetterTogether
  module Billing
    # Contract a payment-processor extension implements and registers with
    # Billing.register_processor. Core never calls a vendor SDK; it calls these
    # methods. Core owns idempotency keys and money state, the adapter executes.
    class ProcessorAdapter
      CONTRACT_VERSION = 1
      CAPABILITIES = %i[checkout portal plan_sync lookups stored_value_credit merchant_accounts].freeze

      # Methods an adapter must override for each capability it advertises, and the
      # keywords each accepts. Money-moving calls always carry an idempotency_key.
      # Every call carries `context:` (a Billing::ProcessorContext): the platform
      # and processor account the call is for. Adapters must use it instead of
      # reading global environment variables, so one platform never acts through
      # another platform's account.
      CAPABILITY_METHODS = {
        checkout: { create_checkout_session: %i[context owner plan success_url cancel_url idempotency_key metadata],
                    sync_checkout_session: %i[context checkout_session_id] },
        portal: { create_portal_session: %i[context owner return_url] },
        plan_sync: { sync_plan: %i[context plan idempotency_key],
                     fetch_price: %i[context processor_price_id],
                     fetch_product: %i[context processor_product_id] },
        lookups: { lookup: %i[context kind search scope limit] },
        stored_value_credit: { credit_balance: %i[context beneficiary amount_cents currency idempotency_key metadata],
                               reverse_credit: %i[context credit_reference amount_cents idempotency_key reason] },
        merchant_accounts: { merchant_onboarding_link: %i[context owner refresh_url return_url],
                             sync_merchant_account: %i[context merchant_account] }
      }.freeze

      # What an adapter may do with a processor-backed field once the processor-side
      # object exists. Anything an adapter does not declare is treated as :create_only.
      FIELD_RULES = %i[create_only updatable].freeze

      class ContractError < StandardError; end
      class UnsupportedCapabilityError < StandardError; end

      # A lookup or fetch the processor could not answer (it is unreachable, rate
      # limited, or rejected the request). The message is shown to a steward, so it
      # must be safe to display: no keys, no raw vendor text.
      class LookupError < StandardError; end

      # Checks an adapter is usable: it inherits this contract, implements the
      # supported contract version, and (when `name` is the name it was registered
      # under) reports that same processor name, so events and plans stored under
      # the registered name always resolve back to the adapter that handles them.
      def self.verify!(adapter, name: nil)
        raise ContractError, "#{adapter.class} must inherit #{self.name}" unless adapter.is_a?(self)
        unless adapter.contract_version == CONTRACT_VERSION
          raise ContractError, "#{adapter.class} implements contract #{adapter.contract_version}, core expects #{CONTRACT_VERSION}"
        end
        if name && adapter.processor_name.to_s != name.to_s
          raise ContractError, "#{adapter.class} is registered as #{name} but reports processor_name #{adapter.processor_name}"
        end

        adapter
      end

      def contract_version = CONTRACT_VERSION

      # Short processor key, e.g. :stripe. Matches Pay's processor name.
      def processor_name = raise(NotImplementedError, "#{self.class}#processor_name")

      def capabilities = []

      def supports?(capability) = capabilities.include?(capability.to_sym)

      # Pay webhook event names this adapter wants delivered, e.g. "stripe.invoice.paid".
      def webhook_event_types = []

      # Turns a vendor webhook event (as Pay delivers it) into a Hash for the event log:
      #   event_id:, event_type:, payload: Hash   (required)
      #   occurred_at:  when the processor says the event happened (ordering input)
      #   platform_id:  the platform it is for, when the event names one
      #   account_ref:  the processor account it came from, to be matched to a platform
      # With neither platform_id nor account_ref, the event goes to the only platform that
      # has billing configured for this processor; if that is ambiguous it is refused
      # (see Billing::WebhookDispatcher). Take no tenant from global state here.
      def normalize_webhook(_vendor_event) = raise(NotImplementedError, "#{self.class}#normalize_webhook")

      # Processes one logged event (read event.payload) for the platform and processor
      # account in `context`, and returns a Billing::EventResult.
      #
      # This MUST be idempotent: a job that fails after the adapter acted is retried, and
      # a replayed event runs again. Use the event id (and, for a write, a key derived from
      # it) to make repeating it harmless.
      def process_event(event:, context:) = raise(NotImplementedError, "#{self.class}#process_event")

      # Returns a copy of a raw webhook payload that is safe to store (no PII, no secrets).
      def sanitize_payload(_payload) = raise(NotImplementedError, "#{self.class}#sanitize_payload")

      # ---- Processor-backed fields -------------------------------------------------
      #
      # Which fields of a Plan the processor will accept a change to after it has created
      # them, as { field => :create_only | :updatable }. Core locks a create-only field
      # once the plan is linked, so a steward cannot change in Community Engine what the
      # processor will not change (and so the two cannot drift). A field not listed is
      # treated as :create_only, the safe default for processors that say nothing.
      # Plan fields: name, description, active, amount_cents, currency, billing_interval,
      # processor_product_id, processor_price_id.
      def field_rules(_resource = :plan) = {}

      # The kinds of option list `lookup` can serve, e.g. %i[products prices currencies
      # intervals]. Used when the adapter advertises :lookups.
      def lookup_kinds = []

      # Fallback lists, used by the plan form when the adapter has no `lookup` for the
      # kind. nil means "core's own list".
      def supported_currencies = nil
      def supported_intervals = nil

      # Capability methods; keywords are listed in CAPABILITY_METHODS.
      #
      # sync_plan creates the processor-side product and price when the plan has no
      # price yet, otherwise updates what the processor allows. It returns a
      # Billing::PlanSyncResult and NEVER writes the plan: core stores the result, which
      # is what keeps a processor-originated change from being pushed straight back.
      # `idempotency_key` must be passed to every processor write.
      def sync_plan(**) = unsupported!(:plan_sync)

      # A Billing::PriceInfo / Billing::ProductInfo for the processor-side object, or
      # nil when it does not exist in this account. Raise LookupError when the processor
      # cannot be asked.
      def fetch_price(**) = unsupported!(:plan_sync)
      def fetch_product(**) = unsupported!(:plan_sync)

      # Options for a processor-backed select, as an Array of Billing::LookupOption
      # (human-readable text, e.g. "Pro (prod_123)" or "USD 10.00 / month, Pro").
      # `kind` is one of lookup_kinds, `search` is what the steward typed, `scope` narrows
      # (e.g. { product: "prod_123" } for prices). Use short SDK timeouts and no retries:
      # this runs while a person waits.
      def lookup(**) = unsupported!(:lookups)

      def create_checkout_session(**) = unsupported!(:checkout)
      def sync_checkout_session(**) = unsupported!(:checkout)
      def create_portal_session(**) = unsupported!(:portal)
      def credit_balance(**) = unsupported!(:stored_value_credit)
      def reverse_credit(**) = unsupported!(:stored_value_credit)
      def merchant_onboarding_link(**) = unsupported!(:merchant_accounts)
      def sync_merchant_account(**) = unsupported!(:merchant_accounts)

      private

      def unsupported!(capability)
        raise UnsupportedCapabilityError, "#{processor_name} does not support #{capability}"
      end
    end
  end
end
