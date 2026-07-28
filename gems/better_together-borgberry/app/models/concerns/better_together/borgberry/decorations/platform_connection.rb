# frozen_string_literal: true

module BetterTogether
  module Borgberry
    module Decorations
      # Applied to BetterTogether::PlatformConnection by Borgberry::Engine's
      # model registry (config.to_prepare) when this extension is bundled.
      # Moved out of core PlatformConnection as part of the C3/Fleet extraction.
      #
      # No organizer-facing UI ships for these settings in this round — the
      # extension is API/federation-only until a dedicated settings surface
      # is built. See docs/borgberry-ce-integration.md and docs/c3-federation-design.md.
      module PlatformConnection
        extend ActiveSupport::Concern

        # `prepended do`, not `included do` — ModelRegistry applies decorations via
        # `prepend` (needed for JoatuAgreement's super-based hook overrides), and
        # ActiveSupport::Concern only fires `included do` blocks for `include`.
        prepended do
          store_attributes :settings do
            # C3 community contribution token exchange (borgberry federation)
            #
            # Storext's `included do` hook defines `Boolean` as a constant on
            # the INCLUDING CLASS itself (`self::Boolean = ::Axiom::Types::Boolean`,
            # see storext.rb), not a namespace-wide constant — bare `Boolean`
            # resolves fine in core's original PlatformConnection because the
            # block is lexically nested directly inside that class. Here the
            # block is nested inside this decoration module instead, which
            # never had Storext's hook run against it, so bare `Boolean` isn't
            # defined anywhere in this file's nesting chain. Reference the
            # real underlying type directly instead of relying on that
            # per-class constant.
            allow_c3_exchange ::Axiom::Types::Boolean, default: false
            c3_exchange_rate String, default: '1.0' # bilateral rate string, e.g. '1.5' = 1 C3 here = 1.5 C3 there
          end
        end

        # Returns true when both ends have opted in to C3 token exchange
        def allows_c3_exchange?
          allow_c3_exchange? && api_read_enabled?
        end

        def c3_exchange_rate_value
          c3_exchange_rate.to_f.then { |r| r.positive? ? r : 1.0 }
        end
      end
    end
  end
end
