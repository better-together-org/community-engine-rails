# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Respond with Offer from Request' do
  include ActiveJob::TestHelper
  include RequestSpecHelper

  let(:owner_user) { create(:user, :confirmed) }
  let(:responder_user) { create(:user, :confirmed) }
  let(:request_resource) { create(:better_together_joatu_request, creator: owner_user.person) }
  # rubocop:todo RSpec/MultipleExpectations
  scenario 'shows respond with offer button and redirects with source params' do # rubocop:todo RSpec/ExampleLength
    # rubocop:enable RSpec/MultipleExpectations
    visit better_together.joatu_request_path(request_resource, locale: I18n.locale)

    expect(page).to have_link(I18n.t('better_together.joatu.requests.respond_with_offer',
                                     default: 'Respond with Offer'))

    click_link I18n.t('better_together.joatu.requests.respond_with_offer', default: 'Respond with Offer')

    # The app may redirect to the new offer form, render an inline form on the
    # request page, or navigate to a link that includes source params. Accept
    # any of these as valid: a redirect to the new offer path, hidden inputs
    # with the source values, or a link/form whose href contains the source
    # query params.

    new_offer_path = better_together.new_joatu_offer_path(locale: I18n.locale)

    has_hidden_inputs = page.has_selector?(
      "input[name='joatu_offer[response_links_as_response_attributes][0][source_type]'][value='BetterTogether::Joatu::Request']", visible: :hidden # rubocop:disable Layout/LineLength
    ) &&
                        page.has_selector?(
                          "input[name='joatu_offer[response_links_as_response_attributes][0][source_id]'][value='#{request_resource.id}']", visible: :hidden # rubocop:disable Layout/LineLength
                        )

    has_new_offer_redirect = current_path == new_offer_path

    has_link_with_params = page.has_css?("a[href*='#{new_offer_path}'][href*='source_type'][href*='#{request_resource.id}']") || # rubocop:disable Layout/LineLength
                           page.has_css?("form[action*='#{new_offer_path}'][action*='source_type']")

    expect(has_hidden_inputs || has_new_offer_redirect || has_link_with_params).to be true
  end
end
