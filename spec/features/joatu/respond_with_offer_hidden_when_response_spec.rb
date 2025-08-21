# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Respond with Offer visibility' do
  include RequestSpecHelper

  let!(:user) { create(:user) }
  let!(:other)  { create(:user) }

  before do
    configure_host_platform
    # sign in the offer creator and create a request response owned by other
    login_as(other, scope: :user)
    @offer = create(:better_together_joatu_offer, creator: user.person)
    @request = create(:better_together_joatu_request, creator: other.person)
    # rubocop:todo RSpec/InstanceVariable
    BetterTogether::Joatu::ResponseLink.create!(source: @offer, response: @request, creator: other.person)
    # rubocop:enable RSpec/InstanceVariable

    logout(:user)
    login_as(user, scope: :user)
  end

  it 'does not render Respond with Offer button on a request that is a response to my offer' do
    visit better_together.joatu_request_path(@request, locale: I18n.locale) # rubocop:todo RSpec/InstanceVariable
    expect(page).not_to have_selector('a', text: I18n.t('better_together.joatu.requests.show.respond_with_offer'))
  end
end
