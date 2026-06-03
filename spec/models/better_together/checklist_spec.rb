# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Checklist do
  it_behaves_like 'an indexed searchable model', :better_together_checklist

  it 'has a valid factory' do
    expect(build(:better_together_checklist)).to be_valid
  end

  describe '#as_indexed_json' do
    it 'includes the checklist title and routing fields' do
      checklist = create(:better_together_checklist, title: 'Borgberry Launch Checklist')

      expect(checklist.as_indexed_json).to include(
        'title' => 'Borgberry Launch Checklist',
        'slug' => checklist.slug,
        'identifier' => checklist.identifier
      )
    end
  end
end
