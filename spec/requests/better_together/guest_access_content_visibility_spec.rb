# frozen_string_literal: true

require 'rails_helper'

# A guest-access link opens a private platform to a visitor who has no account.
# The platform privacy ceiling caps public content on a private platform to
# members, so without a guest exception the link got past the sign-in wall and
# then showed only the promo page and 404s instead of the platform's content.
RSpec.describe 'Guest access content visibility' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:guest_access) do
    create(:better_together_platform_invitation, status: 'pending', locale: locale.to_s, invitable: host_platform)
  end
  let(:public_page) do
    create(:better_together_page, slug: 'guest-public', identifier: 'guest-public', protected: false,
                                  published_at: 1.day.ago, privacy: 'public').tap do |page|
      page.page_blocks.create!(block: create(:content_markdown, markdown_source: 'Guest visible words'), position: 0)
    end
  end
  let(:private_page) do
    create(:better_together_page, slug: 'guest-private', identifier: 'guest-private', protected: false,
                                  published_at: 1.day.ago, privacy: 'private')
  end

  before do
    configure_host_platform
    host_platform.update!(privacy: 'private')
    host_platform.community.update!(privacy: 'private')
    public_page
    private_page
  end

  it 'shows public pages to a visitor holding a valid guest link' do
    get better_together.home_page_path(locale:, invitation_code: guest_access.token)
    get better_together.render_page_path(path: public_page.slug, locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Guest visible words')
  end

  it 'keeps private pages hidden from a guest' do
    get better_together.home_page_path(locale:, invitation_code: guest_access.token)
    get better_together.render_page_path(path: private_page.slug, locale:)

    expect(response).to have_http_status(:not_found)
  end

  it 'still hides public pages from a visitor without a guest link' do
    get better_together.render_page_path(path: public_page.slug, locale:)

    expect(response).to redirect_to(better_together.new_user_session_path(locale:))
  end

  it 'hides public pages again once the guest session has expired' do
    get better_together.home_page_path(locale:, invitation_code: guest_access.token)
    guest_access.destroy!
    get better_together.render_page_path(path: public_page.slug, locale:)

    expect(response).to redirect_to(better_together.new_user_session_path(locale:))
  end
end
