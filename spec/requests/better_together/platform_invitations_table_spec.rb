# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform invitations table', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.host.first }
  let(:community_role) { create(:better_together_role, :community_role) }
  let(:platform_role) { create(:better_together_role, :platform_role) }

  before do
    create(:better_together_platform_invitation,
           invitable: platform,
           invitee_email: 'roles@example.com',
           community_role: community_role,
           platform_role: platform_role)
  end

  it 'renders community and platform roles' do
    get better_together.platform_platform_invitations_path(platform, locale: locale)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(community_role.name)
    expect(response.body).to include(platform_role.name)
  end
end
