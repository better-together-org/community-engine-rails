# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActiveStorage direct uploads', :no_auth do
  # rails_helper.rb includes BetterTogether::Engine.routes.url_helpers after
  # Rails.application.routes.url_helpers for request specs (module include order:
  # later wins), and the engine's url_helpers module falls back to a generic,
  # wrong url_for(controller:, action:) resolution for any route name it doesn't
  # itself define -- including this Rails-core one. Call it fully-qualified to
  # bypass the shadowing.
  let(:direct_uploads_path) { Rails.application.routes.url_helpers.rails_direct_uploads_path }

  let(:blob_params) do
    {
      blob: {
        filename: 'avatar.png',
        byte_size: 6120,
        checksum: Digest::MD5.base64digest('test'),
        content_type: 'image/png'
      }
    }
  end

  let(:token) do
    Rails.application.message_verifier(:direct_upload).generate(
      { path: '/en/users/sign_up', iat: Time.current.to_i }, expires_in: 30.minutes
    )
  end

  def limit_to(bytes)
    host = BetterTogether::Platform.find_by!(host: true)
    BetterTogether::Quota.find_by!(owner: host, quota_type: 'media_storage').update!(limit: bytes)
  end

  def reservation_for_last_blob
    BetterTogether::QuotaReservation.find_by(subject: ActiveStorage::Blob.order(:created_at).last)
  end

  context 'without a direct-upload token' do
    it 'returns 401 and does not create a blob' do
      expect do
        post direct_uploads_path, params: blob_params, as: :json
      end.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'with a valid direct-upload token' do
    it 'creates the blob as normal' do
      expect do
        post direct_uploads_path, params: blob_params, headers: { 'X-Direct-Upload-Token' => token }, as: :json
      end.to change(ActiveStorage::Blob, :count).by(1)

      expect(response).to have_http_status(:ok)
    end
  end

  context 'when the platform enforces its storage limit (hard mode)' do
    let(:host) { BetterTogether::Platform.find_by!(host: true) }
    let(:headers) { { 'X-Direct-Upload-Token' => token } }

    before do
      BetterTogether::Quotas.sync_limit!(type: 'media_storage', owner: host)
      host.set_quota_enforcement!('media_storage', 'hard')
    end

    it 'refuses an upload that would pass the limit, before any blob exists, with a message' do
      limit_to(1_000)

      expect { post direct_uploads_path, params: blob_params, headers:, as: :json }.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq(I18n.t('better_together.quotas.storage_limit_reached'))
      expect(BetterTogether::QuotaReservation.where(quota_type: 'media_storage')).to be_empty
    end

    it 'refuses a declared size above the cap, however much room there is, and holds nothing' do
      limit_to(10**15)
      huge = blob_params.deep_merge(blob: { byte_size: BetterTogether::Quotas::DirectUploadReservation::MAX_DECLARED_BYTES + 1 })

      expect { post direct_uploads_path, params: huge, headers:, as: :json }.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(BetterTogether::QuotaReservation.where(quota_type: 'media_storage')).to be_empty
    end

    it 'lets an upload that fits through, and ties the hold it made to the blob' do
      limit_to(100_000)

      expect { post direct_uploads_path, params: blob_params, headers:, as: :json }.to change(ActiveStorage::Blob, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(reservation_for_last_blob).to have_attributes(amount: 6120, status: 'held', platform_id: host.id)
    end

    it 'does not let a second upload through when the first has taken the room' do
      limit_to(10_000)

      post direct_uploads_path, params: blob_params, headers:, as: :json
      expect(response).to have_http_status(:ok)
      post direct_uploads_path, params: blob_params, headers:, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'lets an upload through if the quota code itself fails, and records the failure' do
      allow(BetterTogether::Quotas).to receive(:reserve!).and_raise(StandardError, 'quota bug')
      allow(BetterTogether).to receive(:report_error)

      expect { post direct_uploads_path, params: blob_params, headers:, as: :json }.to change(ActiveStorage::Blob, :count).by(1)

      expect(BetterTogether).to have_received(:report_error)
    end
  end

  context 'when the platform only records usage (the default)' do
    it 'never refuses, however little room is left' do
      host = BetterTogether::Platform.find_by!(host: true)
      BetterTogether::Quotas.sync_limit!(type: 'media_storage', owner: host)
      BetterTogether::Quota.find_by!(owner: host, quota_type: 'media_storage').update!(limit: 1)

      post direct_uploads_path, params: blob_params, headers: { 'X-Direct-Upload-Token' => token }, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  context 'with an expired direct-upload token' do
    let(:expired_token) do
      travel_to(35.minutes.ago) do
        Rails.application.message_verifier(:direct_upload).generate(
          { path: '/en/users/sign_up', iat: Time.current.to_i }, expires_in: 30.minutes
        )
      end
    end

    it 'returns 401 and does not create a blob' do
      expect do
        post direct_uploads_path, params: blob_params, headers: { 'X-Direct-Upload-Token' => expired_token },
                                  as: :json
      end.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'media_storage reservation' do
    let(:headers) { { 'X-Direct-Upload-Token' => token } }

    it 'holds the blob byte size against the signed-in person, not the platform' do
      user = find_or_create_test_user('direct-upload-quota@example.test')
      login(user.email, AutomaticTestConfiguration::DEFAULT_TEST_USER_PASSWORD)

      post direct_uploads_path, params: blob_params, headers:, as: :json

      reservation = reservation_for_last_blob
      expect(reservation.owner).to eq(user.person)
      expect(reservation.actor).to eq(user.person)
      expect(reservation.amount).to eq(6120)
      expect(reservation).to be_status_held
    end

    it 'falls back to the platform owner for a pre-auth upload' do
      post direct_uploads_path, params: blob_params, headers:, as: :json

      expect(reservation_for_last_blob.owner).to eq(BetterTogether::Quotas::OwnerResolver.platform_fallback)
    end

    it 'reserves nothing when the upload is refused' do
      expect do
        post direct_uploads_path, params: blob_params, as: :json
      end.not_to change(BetterTogether::QuotaReservation, :count)
    end
  end
end
