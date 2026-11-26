# frozen_string_literal: true

module BetterTogether
  module Billing
    # Which platform's processor account a call is for. Every adapter call carries
    # one (`context:`), so adapters never reach for global environment variables
    # and one platform can never act through another platform's account.
    #
    #   platform    - the tenant the call is made for (required)
    #   processor   - the registered processor name, as a Symbol
    #   source      - where the credentials come from. `:environment` means the
    #                 adapter reads the processor's standard environment variables or
    #                 Rails credentials; the host platform is the only platform that
    #                 has such a context today.
    #   account_ref - the processor-side account this context stands for, when known
    #                 (used to attribute webhooks to a platform)
    #   credentials - reserved for per-platform, database-backed credentials
    ProcessorContext = Data.define(:platform, :processor, :source, :account_ref, :credentials) do
      def initialize(platform:, processor:, source: :environment, account_ref: nil, credentials: nil)
        raise ArgumentError, 'a processor context needs a platform' if platform.nil?

        super(platform:, processor: processor.to_sym, source: source.to_sym, account_ref:, credentials: credentials&.freeze)
      end

      def environment? = source == :environment
    end
  end
end
