# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Respond with Request visibility' do
  let!(:person) { create(:person) }
  let!(:other)  { create(:person) }

  before do
    # sign in the request creator and create an offer response owned by other
    login_as(other, scope: :person)
    # create a request belonging to person
    @request = create(:better_together_joatu_request, creator: person)
    # create an offer that is a response to the request (nested attributes or direct link)
    @offer = create(:better_together_joatu_offer, creator: other)
    # create explicit response link: offer is response to request
    # rubocop:todo RSpec/InstanceVariable
    BetterTogether::Joatu::ResponseLink.create!(source: @request, response: @offer, creator: other)
    # rubocop:enable RSpec/InstanceVariable

    # sign in as the request creator to view the offer
    logout(:person)
    login_as(person, scope: :person)
  end

  it 'does not render Respond with Request button on an offer that is a response to my request' do
    visit better_together.joatu_offer_path(@offer, locale: I18n.locale) # rubocop:todo RSpec/InstanceVariable
    expect(page).not_to have_selector('a', text: I18n.t('better_together.joatu.offers.show.respond_with_request'))
  end
end
