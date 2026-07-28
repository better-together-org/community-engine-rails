# frozen_string_literal: true

module BetterTogether
  module Borgberry
    module Decorations
      # Applied to BetterTogether::Person by Borgberry::Engine's model registry
      # (config.to_prepare) when this extension is bundled. Moved out of core
      # Person as part of the C3/Fleet extraction — see docs/borgberry-ce-integration.md.
      module Person
        extend ActiveSupport::Concern

        # `prepended do`, not `included do` — ModelRegistry applies decorations via
        # `prepend` (needed for JoatuAgreement's super-based hook overrides), and
        # ActiveSupport::Concern only fires `included do` blocks for `include`.
        prepended do
          has_many :fleet_node_ownerships,
                   as: :owner,
                   class_name: 'BetterTogether::Fleet::NodeOwnership',
                   dependent: :destroy,
                   inverse_of: :owner
          has_many :fleet_nodes,
                   through: :fleet_node_ownerships,
                   source: :node

          # Borgberry fleet identity — portable person identity used across fleets.
          # Fleet node ownership is tracked separately through BetterTogether::Fleet::NodeOwnership.
          # borgberry_did: W3C DID derived from operator GPG key (e.g. did:key:z6Mk...)
          #
          # Deterministic encryption preserves find_by(borgberry_did:) lookups while
          # preventing the plaintext DID from being exposed in a database extract.
          # After adding this declaration, existing plaintext values must be re-encrypted
          # via migration 20260415050000_reencrypt_person_borgberry_did.rb.
          encrypts :borgberry_did, deterministic: true
          attr_accessor :borgberry_did_raw # used during enrollment only
        end
      end
    end
  end
end
