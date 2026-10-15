# frozen_string_literal: true

require 'rails_helper'

# Who may fetch the media of a community or of the host brand. The privacy of a record decides:
# public media is for everyone, anything else only for people who may see the record itself.
RSpec.describe 'Community media access', :no_auth do
  let(:png) do
    "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89\x00" \
      "\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82"
  end
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  before do
    host_platform.community.update_columns(privacy: 'public')
    host_platform.update_columns(privacy: 'public')
  end

  after { Warden.test_reset! }

  def media_path(record)
    record.logo.attach(io: StringIO.new(png), filename: 'logo.png', content_type: 'image/png')
    Rails.application.routes.url_helpers.rails_storage_proxy_path(record.logo, only_path: true)
  end

  def community_with_privacy(privacy)
    create(:better_together_community, privacy:)
  end

  def status_for(path)
    get path
    response.status
  end

  %w[community private].each do |privacy|
    context "with a #{privacy} community" do
      let(:path) { media_path(community_with_privacy(privacy)) }

      it 'refuses an anonymous visitor' do
        expect(status_for(path)).to eq(401)
      end

      it 'refuses a signed-in user who is not a member' do
        login_as(create(:better_together_user, :confirmed), scope: :user)
        expect(status_for(path)).to eq(403)
      end

      it 'serves a platform manager' do
        login_as(create(:better_together_user, :confirmed, :platform_manager), scope: :user)
        expect(status_for(path)).to eq(200)
      end
    end
  end

  context 'with a public community' do
    it 'serves an anonymous visitor' do
      expect(status_for(media_path(community_with_privacy('public')))).to eq(200)
    end
  end

  context 'with a private host platform (site branding)' do
    before do
      host_platform.update_columns(privacy: 'private')
      host_platform.community.update_columns(privacy: 'private')
    end

    it 'still serves the host community logo to an anonymous visitor' do
      expect(status_for(media_path(host_platform.community))).to eq(200)
    end
  end
end
