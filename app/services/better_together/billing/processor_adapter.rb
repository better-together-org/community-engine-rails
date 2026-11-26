# frozen_string_literal: true

module BetterTogether
  module Billing
    # Contract a payment-processor extension implements and registers with
    # Billing.register_processor. Core never calls a vendor SDK; it calls these
    # methods. Core owns idempotency keys and money state, the adapter executes.
    class ProcessorAdapter
      # `merchant_accounts` and `transfers` are reserved: the contract names them but core has no
      # caller until payouts exist. (There is no stored-value capability: store credit is a ledger
      # inside Community Engine, not something a processor does.)
      CAPABILITIES = %i[checkout portal catalog_sync lookups merchant_accounts refunds transfers offline_settlement].freeze

      # Methods an adapter must override for each capability it advertises and the
      # keywords each accepts. Money-moving calls always carry an idempotency_key.
      # Every call carries `context:` (a Billing::ProcessorContext): the platform
      # and processor account the call is for. Adapters must use it instead of
      # reading global environment variables, so one platform never acts through
      # another platform's account.
      CAPABILITY_METHODS = {
        # A buyer pays an order through the processor. create_checkout_session returns a CheckoutSession and is given the tax
        # core worked out (`tax_cents` added, `included_tax_cents` inside the prices, `prices_include_tax`): charge it, never recompute;
        # release_payment expires the session or cancels the intent when core lets the order go;
        # reconcile_payment pulls the processor's state for a payment (never trust a payload alone);
        # payment_action_url is where a buyer completes a payment that needs them (a bank confirmation),
        # and receipt_url is the processor's hosted receipt: both return an https URL or nil.
        checkout: { create_checkout_session: %i[context order payment success_url cancel_url idempotency_key metadata
                                                tax_cents included_tax_cents prices_include_tax mode lines],
                    sync_checkout_session: %i[context checkout_session_id],
                    release_payment: %i[context payment idempotency_key],
                    reconcile_payment: %i[context payment],
                    payment_action_url: %i[context order],
                    receipt_url: %i[context payment] },
        portal: { create_portal_session: %i[context owner return_url] },
        catalog_sync: { sync_catalog_item: %i[context item idempotency_key],
                        fetch_price: %i[context processor_price_id],
                        fetch_product: %i[context processor_product_id] },
        lookups: { lookup: %i[context kind search scope limit] },
        merchant_accounts: { merchant_onboarding_link: %i[context owner refresh_url return_url],
                             sync_merchant_account: %i[context merchant_account] },
        # refund returns a RefundResult. Write it with the SDK and the idempotency key, then let Pay sync.
        refunds: { refund: %i[context payment_reference amount_cents currency idempotency_key reason] },
        transfers: { transfer: %i[context destination amount_cents currency idempotency_key metadata] },
        offline_settlement: { instructions_for: %i[context setting order] }
      }.freeze

      # What an adapter may do with a processor-backed field once the processor-side
      # object exists. Anything an adapter does not declare is treated as :create_only.
      FIELD_RULES = %i[create_only updatable].freeze

      # How money reaches the seller. `remote`: the processor takes the payment and tells
      # core by webhook. `manual`: it happens outside anything the platform can see (cash,
      # cheque, e-transfer); the seller confirms receipt and core owns the state machine.
      # `internal`: a ledger inside Community Engine (store credit).
      SETTLEMENT_KINDS = %i[remote manual internal].freeze

      # `automatic`: the processor renews on its own. `manual`: each period is a new pending
      # payment the seller confirms. `none`: one-time payments only.
      RECURRING_MODES = %i[automatic manual none].freeze

      class ContractError < StandardError; end
      class UnsupportedCapabilityError < StandardError; end

      # A lookup or fetch the processor could not answer (it is unreachable, rate
      # limited, or rejected the request). The message is shown to a steward, so it
      # must be safe to display: no keys, no raw vendor text.
      class LookupError < StandardError; end

      extend Verification

      # Short processor key, e.g. :stripe. Matches Pay's processor name.
      def processor_name = raise(NotImplementedError, "#{self.class}#processor_name")

      def capabilities = []

      def supports?(capability) = capabilities.include?(capability.to_sym)

      # Pay webhook event names this adapter wants delivered, e.g. "stripe.charge.refunded".
      # Also Pay's ingestion allow-list: an event nobody subscribed to is dropped, and matching is
      # by prefix. See docs/billing/processor-adapters.md for what Pay handles and what it ignores.
      def webhook_event_types = []

      # ---- Settlement ------------------------------------------------------------
      #
      # See SETTLEMENT_KINDS and RECURRING_MODES. The defaults describe a typical remote
      # processor, so existing adapters need no change.
      def settlement_kind = :remote
      def recurring_mode = :automatic

      # ISO 3166 alpha-2 codes of the countries the method works in, or nil for anywhere.
      # Core hides the method (or refuses to enable it) for a seller outside them.
      def supported_countries = nil

      # False when the platform can neither track nor take a fee on the payment (every
      # manual method). Reports show such sales as "uncollected" instead of zero.
      def fee_collectible? = settlement_kind == :remote

      # Fields a seller fills in so buyers know how to pay (manual methods only): an
      # Array of Billing::InstructionField. Core stores the values encrypted.
      def instruction_fields = []

      # What ProcessorSetting asks of any method Community Engine settles itself (manual or
      # internal). The defaults say "nothing to choose, nothing to check", so a method that
      # has no instructions (store credit) answers safely; OfflineProcessorAdapter overrides them.
      def grant_on_options = []
      def default_grant_on = grant_on_options.first
      def settings_errors(_values) = {}

      # Turns a vendor webhook event (as Pay delivers it) into a Hash for the event log.
      #
      # What Pay delivers depends on the processor (Pay::Webhook#rehydrated_event): a
      # `::Stripe::Event` for Stripe (not a Hash: use its readers), the event's `data` only for
      # Paddle Billing (so no envelope and no event id to read), a notification object for
      # Braintree. Read what your processor really passes.
      #
      #   event_id:, event_type:, payload: Hash   (required)
      #   occurred_at:  when the processor says the event happened (ordering input)
      #   platform_id:  the platform it is for, when the event names one
      #   account_ref:  the processor account it came from (Stripe Connect `account`), matched
      #                 to the platform whose context names it; an unknown account is refused
      #   customer_ref: the processor customer id, when the event has one; if a Pay customer
      #                 with that id exists on a DIFFERENT platform than the one resolved, the
      #                 event is refused (Pay's own handlers attribute by customer)
      #   livemode:     false for a test-mode event (keep it in the payload)
      # With neither platform_id nor account_ref, the event goes to the only platform that
      # has billing configured for this processor; if that is ambiguous it is refused
      # (see Billing::WebhookDispatcher). Take no tenant from global state here.
      #
      # `webhook_event_types` is also Pay's ingestion allow-list: Pay's controllers drop any
      # event nobody subscribed to, and matching is by prefix ("stripe.charge.dispute" covers
      # its sub-events).
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
      # Plan fields: name, description, active, amount_cents, currency, billing_interval, interval_count,
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
      # `idempotency_key` must be passed to every processor write.
      # Creates or updates the processor-side product and every price in the CatalogItem that has no
      # `processor_price_id`, and returns a Billing::CatalogSyncResult with a PriceInfo (carrying the CatalogPrice's `ref`) for each
      # price. Never writes a plan, product or price. A price on the processor is immutable: a changed amount is a new
      # CatalogPrice core already made, so create it and leave the old one. `idempotency_key` goes on every processor write.
      def sync_catalog_item(**) = unsupported!(:catalog_sync)

      # A Billing::PriceInfo / Billing::ProductInfo for the processor-side object, or
      # nil when it does not exist in this account. Raise LookupError when the processor
      # cannot be asked.
      def fetch_price(**) = unsupported!(:catalog_sync)
      def fetch_product(**) = unsupported!(:catalog_sync)

      # Options for a processor-backed select, as an Array of Billing::LookupOption
      # (human-readable text, e.g. "Pro (prod_123)" or "USD 10.00 / month, Pro").
      # `kind` is one of lookup_kinds, `search` is what the steward typed, `scope` narrows
      # (e.g. { product: "prod_123" } for prices). Use short SDK timeouts and no retries:
      # this runs while a person waits.
      def lookup(**) = unsupported!(:lookups)

      # It is also given `mode:` (`:payment` or `:subscription`) and `lines:` (Billing::CheckoutLine, each a
      # processor price id or inline InlinePrice) so it builds the session from core's view of the order instead of its own.
      def create_checkout_session(**) = unsupported!(:checkout)
      def sync_checkout_session(**) = unsupported!(:checkout)
      def release_payment(**) = unsupported!(:checkout)
      def reconcile_payment(**) = unsupported!(:checkout)
      def payment_action_url(**) = unsupported!(:checkout)
      def receipt_url(**) = unsupported!(:checkout)
      def create_portal_session(**) = unsupported!(:portal)
      def merchant_onboarding_link(**) = unsupported!(:merchant_accounts)
      def sync_merchant_account(**) = unsupported!(:merchant_accounts)
      def refund(**) = unsupported!(:refunds)
      def transfer(**) = unsupported!(:transfers)

      # What the buyer is shown to pay outside the platform: a Hash of label key to value,
      # built from the seller's stored values. Never log it or put it in an email.
      def instructions_for(**) = unsupported!(:offline_settlement)

      private

      def unsupported!(capability)
        raise UnsupportedCapabilityError, "#{processor_name} does not support #{capability}"
      end
    end
  end
end
