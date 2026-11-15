# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the non-blocking privacy ceiling notice that the docs screenshot targets.
RSpec.describe 'Privacy ceiling notice DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  include ActionView::RecordIdentifier

  let(:host_platform) { BetterTogether::Platform.find_by!(host: true) }

  def edit_page_path(page)
    "/#{I18n.default_locale}/pages/#{page.slug}/edit"
  end

  it 'warns on the page edit form when the platform is not public and keeps every option selectable' do
    host_platform.update_columns(privacy: 'private') # rubocop:disable Rails/SkipsModelValidations
    page = create(:better_together_page, platform: host_platform, privacy: 'public')

    get edit_page_path(page)

    expect(response).to have_http_status(:ok)
    notice_id = dom_id(page, :privacy_ceiling_notice)
    expect(response.body).to include(%(id="#{notice_id}"))
    expect(response.body).to include('role="note"')
    expect(response.body).to include(%(aria-describedby="#{notice_id}"))
    expect(response.body).not_to match(/<option[^>]*value="public"[^>]*disabled/)
  end

  it 'omits the notice when the platform and community are public' do
    host_platform.update_columns(privacy: 'public') # rubocop:disable Rails/SkipsModelValidations
    host_platform.community.update_columns(privacy: 'public') # rubocop:disable Rails/SkipsModelValidations
    page = create(:better_together_page, platform: host_platform, community: host_platform.community, privacy: 'public')

    get edit_page_path(page)

    expect(response.body).not_to include(dom_id(page, :privacy_ceiling_notice))
  end
end
