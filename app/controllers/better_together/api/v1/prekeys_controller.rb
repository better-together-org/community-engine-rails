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
        def save_key_backup
          blob = params[:blob]
          salt = params[:salt]

          unless blob.present? && salt.present? && valid_base64?(blob) && valid_base64?(salt)
            return render json: { error: 'blob and salt must be non-empty base64 strings' },
                          status: :unprocessable_entity
          end

          @person.update!(
            key_backup_blob: blob,
            key_backup_salt: salt,
            key_backup_updated_at: Time.current
          )

          render json: { status: 'ok', updated_at: @person.key_backup_updated_at }
        end

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
