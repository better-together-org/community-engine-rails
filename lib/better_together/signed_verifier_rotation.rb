# frozen_string_literal: true

module BetterTogether
  # Keeps signed ids verifiable whichever key-derivation digest the host app booted with.
  #
  # Rails sets ActiveSupport::KeyGenerator.hash_digest_class (SHA256 under load_defaults 7.0+) in an
  # after_initialize hook. If another after_initialize hook builds a verifier first (ActiveStorage does),
  # the app's key generator is cached with SHA1 and every signed global id minted under SHA256, such as
  # the sgid in a stored Action Text attachment, stops verifying and renders as a held attachment.
  # Which hook wins depends on initializer ordering, so a deploy can flip it. Accepting both derivations
  # makes verification independent of boot order; signing still uses the primary key.
  module SignedVerifierRotation
    DIGESTS = [OpenSSL::Digest::SHA256, OpenSSL::Digest::SHA1].freeze

    class << self
      def install!(app)
        rotate(SignedGlobalID.verifier, salt: 'signed_global_ids', secret_key_base: app.secret_key_base)
      end

      def rotate(verifier, salt:, secret_key_base:)
        return unless verifier.respond_to?(:rotate) && secret_key_base.present?

        DIGESTS.each do |digest|
          verifier.rotate(ActiveSupport::KeyGenerator.new(secret_key_base, iterations: 1000, hash_digest_class: digest).generate_key(salt))
        end
        verifier
      end
    end
  end
end
