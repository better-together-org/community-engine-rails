# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/people/_mention' do
  let(:person) { create(:better_together_person, name: 'Ada Example') }

  before do
    view.extend BetterTogether::ImageHelper
    allow(view).to receive_messages(mention_profile_path: '/p/ada', safe_current_person: nil)
  end

  it 'leaves a gap between the avatar and the name' do
    render partial: 'better_together/people/mention', locals: { person: }

    avatar_wrapper = Capybara.string(rendered).find("##{dom_id(person, :mention)} > div.h-50", match: :first)
    expect(avatar_wrapper[:class].split).to include('me-2')
  end
end
