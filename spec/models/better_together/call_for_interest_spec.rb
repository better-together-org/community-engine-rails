# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CallForInterest do
  it_behaves_like 'an indexed searchable model', :better_together_call_for_interest

  it 'has a valid factory' do
    expect(build(:better_together_call_for_interest)).to be_valid
  end

  describe '#as_indexed_json' do
    it 'includes translated name and description content' do
      call_for_interest = create(
        :better_together_call_for_interest,
        name: 'Borgberry Cooperative Hosting',
        description: 'Looking for members interested in shared hosting support.'
      )

      expect(call_for_interest.as_indexed_json).to include(
        'name' => 'Borgberry Cooperative Hosting',
        'description' => 'Looking for members interested in shared hosting support.'
      )
    end
  end
end
