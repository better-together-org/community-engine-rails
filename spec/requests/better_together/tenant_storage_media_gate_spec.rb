# frozen_string_literal: true

require 'rails_helper'

# A blob stored on one platform's own storage service is served only on that platform.
RSpec.describe 'Tenant storage media gate', :no_auth do
  let(:png) do
    "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89\x00" \
      "\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82"
  end
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:community) { create(:better_together_community, privacy: 'public') }

  before do
    host_platform.community.update_columns(privacy: 'public')
    host_platform.update_columns(privacy: 'public')
    community.logo.attach(io: StringIO.new(png), filename: 'logo.png', content_type: 'image/png')
  end

  def path
    Rails.application.routes.url_helpers.rails_storage_proxy_path(community.logo, only_path: true)
  end

  it 'serves a blob on the default service' do
    get path

    expect(response).to have_http_status(:ok)
  end

  it 'hides a blob owned by another platform' do
    other = create(:better_together_storage_configuration)
    community.logo.blob.update_columns(service_name: other.storage_key)

    get path

    expect(response).to have_http_status(:not_found)
  end

  it 'serves a blob owned by the current platform', :aggregate_failures do
    config = create(:better_together_storage_configuration, platform: host_platform)
    host_platform.update!(storage_configuration_id: config.id)
    Current.set(platform: host_platform) do
      community.logo.attach(io: StringIO.new(png), filename: 'logo.png', content_type: 'image/png')
    end

    expect(community.logo.blob.service_name).to eq(config.storage_key)
    get path

    expect(response).to have_http_status(:ok)
  end
end
