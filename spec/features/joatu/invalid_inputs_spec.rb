# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Joatu invalid inputs', type: :feature do
  scenario 'fails to create a request without a name' do
    person = create(:better_together_person)
    request = BetterTogether::Joatu::Request.new(description: 'Need help', creator: person)

    expect(request.valid?).to be(false)
    expect(request.errors[:name]).to be_present
  end
end
