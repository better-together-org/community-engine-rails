# frozen_string_literal: true

require 'rails_helper'

# SEC-06: the invoice and receipt files belong to the platform's record keeping, so the buyer
# may read them but never rewrite, publish or delete them through the ordinary uploads routes.
# The API answers a denied write with 404 so it does not reveal the record.
RSpec.describe 'Billing document uploads', :no_auth do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:user) { find_or_create_test_user("doc-buyer-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:buyer) { user.person }
  let!(:order) { place_order }
  let(:upload) { BetterTogether::Billing::Orders::GenerateDocument.call(order).upload }
  let(:headers) { api_auth_headers(user, token: api_sign_in_and_get_token(user)).merge('Content-Type' => 'application/vnd.api+json') }

  def patch_upload(attributes)
    body = { data: { type: 'uploads', id: upload.id, attributes: } }.to_json
    patch "/api/v1/uploads/#{upload.id}", params: body, headers:
  end

  it 'lets the buyer read their own document through the policy' do
    expect(BetterTogether::UploadPolicy.new(user, upload).download?).to be(true)
  end

  it 'does not let the buyer make the document public', :aggregate_failures do
    patch_upload(privacy: 'public')

    expect(response).to have_http_status(:not_found)
    expect(upload.reload).to be_privacy_private
  end

  it 'does not let the buyer rename the document', :aggregate_failures do
    original = upload.name
    patch_upload(name: 'forged')

    expect(response).to have_http_status(:not_found)
    expect(upload.reload.name).to eq(original)
  end

  it 'does not let the buyer delete the document', :aggregate_failures do
    delete "/api/v1/uploads/#{upload.id}", headers: headers

    expect(response).not_to have_http_status(:no_content)
    expect(BetterTogether::Upload.exists?(upload.id)).to be(true)
  end

  it 'denies the buyer update and destroy in the policy', :aggregate_failures do
    policy = BetterTogether::UploadPolicy.new(user, upload)

    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
  end
end
