# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActiveStorage direct uploads' do
  # RequestSpecHelper includes BetterTogether::Engine.routes.url_helpers after
  # Rails.application.routes.url_helpers (module include order: later wins), and the
  # engine's url_helpers module falls back to a generic, wrong url_for(controller:,
  # action:) resolution for any route name it doesn't itself define -- including this
  # Rails-core one. Call it fully-qualified to bypass the shadowing.
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
end
