# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventHost do
  subject(:event_host) { build(:better_together_event_host) }

  it 'has a valid factory' do
    expect(event_host).to be_valid
  end

  it 'requires a host association' do
    event_host.host = nil

    expect(event_host).not_to be_valid
    expect(event_host.errors[:host]).to be_present
  end
end
