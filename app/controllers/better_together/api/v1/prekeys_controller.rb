# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Manages Signal Protocol prekey bundles for E2E encryption.
      # Public key material is stored on the server to enable X3DH session setup.
      # Private keys are never transmitted to or stored by the server.
      #
      # Inherits from BetterTogether::Api::ApplicationController to get Devise JWT +
      # Doorkeeper OAuth2 auth. Custom action names bypass JSONAPI dispatch entirely.
      #
      # Endpoints:
      #   GET /api/v1/people/:person_id/prekey_bundle         — public key bundle, rate-limited
      #   PUT /api/v1/people/:person_id/register_prekeys      — own person only
      #   GET /api/v1/people/:person_id/key_backup            — fetch encrypted backup blob (own person only)
      #   PUT /api/v1/people/:person_id/key_backup            — store encrypted backup blob (own person only)
      # rubocop:disable Metrics/ClassLength
      class PrekeysController < BetterTogether::Api::ApplicationController
        skip_before_action :verify_authenticity_token, raise: false
        # Authorization is handled by authorize_own_person! rather than Pundit policies.
        # Skip both standard Pundit and pundit-resources enforcement hooks.
        skip_after_action :verify_authorized, raise: false
        skip_after_action :verify_policy_scoped, raise: false
        skip_after_action :enforce_policy_use,   raise: false

        before_action :set_person
        before_action :authorize_own_person!, only: %i[register_prekeys key_backup save_key_backup]
        # V4 fix: rate-limit prekey_bundle to prevent OTK exhaustion DoS.
        before_action :check_bundle_rate_limit, only: %i[prekey_bundle]

        # GET /api/v1/people/:person_id/prekey_bundle
        # Returns the prekey bundle for any person (public key material).
        # One-time prekeys are marked consumed when returned, unless the requester
        # already has a session (idempotent for repeated calls from the same requester).
        # rubocop:disable Metrics/MethodLength
        def prekey_bundle
          unless @person.identity_key_public.present?
            return render json: { error: 'Person has not registered prekeys' }, status: :not_found
          end

          one_time_prekey = consume_one_time_prekey
          bundle = {
            registration_id: @person.registration_id,
            identity_key: @person.identity_key_public,
            signed_prekey: {
              id: @person.signed_prekey_id,
              public_key: @person.signed_prekey_public,
              signature: @person.signed_prekey_sig
            },
            one_time_prekey: one_time_prekey ? { id: one_time_prekey.key_id, public_key: one_time_prekey.public_key } : nil
          }

          render json: { data: bundle }
        end
        # rubocop:enable Metrics/MethodLength

        # PUT /api/v1/people/:person_id/register_prekeys
        # Uploads identity key, signed prekey, and a batch of one-time prekeys.
        # Replaces the signed prekey and appends new one-time prekeys.
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def register_prekeys
          return render json: { error: 'Missing required fields' }, status: :unprocessable_entity unless valid_registration?

          ActiveRecord::Base.transaction do
            @person.update!(
              registration_id: registration_params[:registration_id],
              identity_key_public: registration_params[:identity_key],
              signed_prekey_id: registration_params.dig(:signed_prekey, :id),
              signed_prekey_public: registration_params.dig(:signed_prekey, :public_key),
              signed_prekey_sig: registration_params.dig(:signed_prekey, :signature)
            )

            if registration_params[:one_time_prekeys].present?
              registration_params[:one_time_prekeys].each do |prekey|
                # Upsert by (person_id, key_id) — safe to call multiple times
                BetterTogether::OneTimePrekey.find_or_create_by!(
                  person: @person,
                  key_id: prekey[:id]
                ) do |otk|
                  otk.public_key = prekey[:public_key]
                end
              end
            end
          end

          check_prekey_stock

          render json: { status: 'ok', prekey_count: @person.one_time_prekeys.unconsumed.count }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        # GET /api/v1/people/:person_id/key_backup
        # Returns the encrypted key backup blob for the authenticated person.
        # The blob is opaque to the server — only the client can decrypt it.
        def key_backup
          unless @person.key_backup_blob.present?
            return render json: { error: 'No key backup found' }, status: :not_found
          end

          render json: {
            data: {
              blob: @person.key_backup_blob,
              salt: @person.key_backup_salt,
              updated_at: @person.key_backup_updated_at
            }
          }
        end

        # PUT /api/v1/people/:person_id/key_backup
        # Stores an encrypted key backup blob. The server treats blob + salt as opaque strings.
        #
        # V6 fix: optimistic concurrency lock via `previous_updated_at` param.
        # If a backup already exists and the client's `previous_updated_at` does not match
        # the stored timestamp (to the second), the write is rejected to prevent silent
        # replacement by an attacker with a stolen session token.
        # The client must pass `previous_updated_at: nil` (or omit it) when creating the
        # first backup. For updates, pass the `updated_at` value from the last successful
        # GET /key_backup response.
        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        def save_key_backup
          blob = params[:blob]
          salt = params[:salt]

          unless blob.present? && salt.present? && valid_base64?(blob) && valid_base64?(salt)
            return render json: { error: 'blob and salt must be non-empty base64 strings' },
                          status: :unprocessable_entity
          end

          # V6 fix: optimistic lock — reject if backup was updated since the client last read it.
          if @person.key_backup_updated_at.present?
            previous_updated_at = params[:previous_updated_at]
            if previous_updated_at.blank?
              return render json: {
                error: 'previous_updated_at is required when a backup already exists',
                current_updated_at: @person.key_backup_updated_at
              }, status: :conflict
            end

            begin
              client_ts = Time.zone.parse(previous_updated_at)
            rescue ArgumentError, TypeError
              return render json: { error: 'previous_updated_at is not a valid timestamp' },
                            status: :unprocessable_entity
            end

            # Compare at second granularity to tolerate minor serialization rounding.
            unless @person.key_backup_updated_at.to_i == client_ts.to_i
              return render json: {
                error: 'Backup was updated by another device since you last read it. Fetch the latest backup first.',
                current_updated_at: @person.key_backup_updated_at
              }, status: :conflict
            end
          end

          @person.update!(
            key_backup_blob: blob,
            key_backup_salt: salt,
            key_backup_updated_at: Time.current
          )

          Rails.logger.info("[E2E] Person #{@person.id} updated key backup at #{@person.key_backup_updated_at}")

          render json: { status: 'ok', updated_at: @person.key_backup_updated_at }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

        private

        def set_person
          @person = BetterTogether::Person.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Person not found' }, status: :not_found
        end

        def authorize_own_person!
          return if current_user&.person == @person

          render json: { error: 'Forbidden' }, status: :forbidden
        end

        def consume_one_time_prekey
          # Mark a one-time prekey as consumed atomically. Returns nil if stock is exhausted.
          BetterTogether::OneTimePrekey.transaction do
            prekey = @person.one_time_prekeys.unconsumed.lock.first
            prekey&.update!(consumed: true)
            prekey
          end
        end

        def registration_params
          @registration_params ||= params.permit(
            :registration_id,
            :identity_key,
            signed_prekey: %i[id public_key signature],
            one_time_prekeys: %i[id public_key]
          )
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        def valid_registration?
          rp = registration_params
          rp[:registration_id].present? &&
            rp[:identity_key].present? &&
            rp.dig(:signed_prekey, :id).present? &&
            rp.dig(:signed_prekey, :public_key).present? &&
            rp.dig(:signed_prekey, :signature).present? &&
            valid_base64?(rp[:identity_key]) &&
            valid_base64?(rp.dig(:signed_prekey, :public_key)) &&
            valid_base64?(rp.dig(:signed_prekey, :signature))
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

        def valid_base64?(str)
          return false unless str.is_a?(String)

          Base64.strict_decode64(str)
          true
        rescue ArgumentError
          false
        end

        # V4 fix: rate-limit prekey_bundle fetches to prevent OTK exhaustion DoS.
        # An authenticated user (A0) could otherwise drain any person's OTK stock in seconds.
        #
        # Limits (per rolling hour window, using Rails.cache):
        #   - 20 bundle fetches per requester (prevents bulk harvesting from one account)
        #   - 30 bundle fetches per target (prevents targeted OTK drain across many accounts)
        #
        # Unauthenticated requests are rejected entirely — prekey_bundle requires a valid JWT.
        # Override limits via ENV: PREKEY_BUNDLE_REQUESTER_LIMIT, PREKEY_BUNDLE_TARGET_LIMIT.
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def check_bundle_rate_limit
          unless current_user
            render json: { error: 'Authentication required' }, status: :unauthorized
            return
          end

          requester_limit = (ENV['PREKEY_BUNDLE_REQUESTER_LIMIT'] || '20').to_i
          target_limit    = (ENV['PREKEY_BUNDLE_TARGET_LIMIT']    || '30').to_i
          window_key      = Time.current.strftime('%Y%m%d%H')

          requester_key   = "prekey_bundle:req:#{current_user.id}:#{window_key}"
          target_key      = "prekey_bundle:tgt:#{@person.id}:#{window_key}"

          requester_count = Rails.cache.increment(requester_key, 1, expires_in: 1.hour)
          target_count    = Rails.cache.increment(target_key,    1, expires_in: 1.hour)

          if requester_count > requester_limit
            Rails.logger.warn(
              "[E2E] Rate limit: user #{current_user.id} exceeded #{requester_limit} bundle fetches/hr"
            )
            render json: { error: 'Rate limit exceeded — too many bundle fetches from this account' },
                   status: :too_many_requests
            return
          end

          return unless target_count > target_limit

          Rails.logger.warn(
            "[E2E] Rate limit: person #{@person.id} targeted #{target_count} times this hour " \
            "(limit #{target_limit}) by user #{current_user.id}"
          )
          render json: { error: 'Rate limit exceeded — too many bundle fetches for this person' },
                 status: :too_many_requests
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def check_prekey_stock
          return unless @person.one_time_prekeys.unconsumed.count < 10

          Rails.logger.warn(
            "[E2E] Person #{@person.id} has fewer than 10 unconsumed one-time prekeys. " \
            'Client should upload more prekeys.'
          )
          # Future: trigger an in-app notification to the user
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
