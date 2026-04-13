# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Checklist do
  it 'has a valid factory' do
    expect(build(:better_together_checklist)).to be_valid
  end
end
