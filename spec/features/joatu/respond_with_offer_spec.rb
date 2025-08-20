# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Respond with Offer from Request' do
  include ActiveJob::TestHelper
  include RequestSpecHelper

  let(:owner_user) { create(:user, :confirmed) }
  let(:responder_user) { create(:user, :confirmed) }
  let(:request_resource) { create(:better_together_joatu_request, creator: owner_user.person) }

  before do
    configure_host_platform
    login_as(responder_user, scope: :user)
  end

  # rubocop:todo RSpec/MultipleExpectations
  scenario 'shows respond with offer button and redirects with source params' do # rubocop:todo RSpec/ExampleLength
    # rubocop:enable RSpec/MultipleExpectations
    visit better_together.joatu_request_path(request_resource, locale: I18n.locale)

    expect(page).to have_link(I18n.t('better_together.joatu.requests.respond_with_offer',
                                     default: 'Respond with Offer'))

    click_link I18n.t('better_together.joatu.requests.respond_with_offer', default: 'Respond with Offer')

    expect(current_path).to eq(better_together.new_joatu_offer_path(locale: I18n.locale))
    expect(page).to have_selector(
      # rubocop:todo Layout/LineLength
      "input[name='joatu_offer[response_links_as_response_attributes][0][source_type]'][value='BetterTogether::Joatu::Request']", visible: :hidden
      # rubocop:enable Layout/LineLength
    )
    expect(page).to have_selector(
      # rubocop:todo Layout/LineLength
      "input[name='joatu_offer[response_links_as_response_attributes][0][source_id]'][value='#{request_resource.id}']", visible: :hidden
      # rubocop:enable Layout/LineLength
    )
  end
end
