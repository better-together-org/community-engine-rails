# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Detached Ed25519 signature over the bytes of MANIFEST.json. Because the manifest lists the
    # sha256 of every other file, one signature covers the whole packet. The signature file is
    # MANIFEST.json.sig (base64). The key id comes from seed.origin.signing_key_id and must map to
    # a trusted public key (PEM). Trusted keys come from `register_key` or from
    # `<key_id>.pem` files in the directories in BETTER_TOGETHER_SEED_TRUSTED_KEYS_DIR
    # (colon separated). A packet is never trusted because it ships its own key.
    module Signature
      SIGNATURE_FILE = 'MANIFEST.json.sig'
      KEY_ID = /\A[A-Za-z0-9._-]{1,128}\z/

      @keys = {}

      class << self
        def register_key(key_id, public_key_pem)
          @keys = @keys.merge(key_id.to_s => public_key_pem.to_s)
        end

        def reset!
          @keys = {}
        end

        # Raw 64-byte Ed25519 signature of the manifest, base64 encoded.
        def sign(manifest_bytes, private_key_pem)
          Base64.strict_encode64(OpenSSL::PKey.read(private_key_pem).sign(nil, manifest_bytes))
        end

        def signed?(root)
          Pathname.new(root).join(SIGNATURE_FILE).file?
        end

        # Returns a Protocol::Report. With require: true an unsigned packet is an error.
        def verify(root, key_id:, require: false, report: Protocol::Report.new)
          root = Pathname.new(root)
          return report if !signed?(root) && !require

          check(root, key_id, report)
          report
        end

        private

        def check(root, key_id, report)
          file = root.join(SIGNATURE_FILE)
          return fail_with(report, 'packet is not signed but a signature is required') unless file.file?
          return fail_with(report, 'packet is signed but declares no seed.origin.signing_key_id') if key_id.blank?
          return fail_with(report, 'signing_key_id has an invalid format') unless KEY_ID.match?(key_id.to_s)

          pem = trusted_pem(key_id.to_s)
          return fail_with(report, "signing key #{key_id} is not trusted on this host") unless pem

          report.add_error(file: SIGNATURE_FILE, message: 'signature does not match MANIFEST.json') unless valid_signature?(root, file, pem)
        rescue ArgumentError, OpenSSL::PKey::PKeyError
          fail_with(report, 'signature or key could not be decoded')
        end

        def valid_signature?(root, file, pem)
          key = OpenSSL::PKey.read(pem)
          raise ArgumentError, 'not an Ed25519 key' unless key.oid == 'ED25519'

          key.verify(nil, Base64.strict_decode64(file.read.strip), root.join('MANIFEST.json').binread)
        end

        def trusted_pem(key_id)
          return @keys[key_id] if @keys.key?(key_id)

          directories.filter_map do |dir|
            candidate = Pathname.new(dir).join("#{key_id}.pem")
            candidate.read if candidate.file? && candidate.realpath.dirname == Pathname.new(dir).realpath
          end.first
        end

        def directories
          ENV.fetch('BETTER_TOGETHER_SEED_TRUSTED_KEYS_DIR', '').split(':').compact_blank
        end

        def fail_with(report, message)
          report.add_error(file: SIGNATURE_FILE, message:)
        end
      end
    end
  end
end
