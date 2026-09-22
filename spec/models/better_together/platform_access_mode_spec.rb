# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Platform do
  it 'uses invitation mode when invitations are required' do
    platform = build(:better_together_platform, requires_invitation: true)

    expect(platform.access_mode).to eq(:invitation)
    expect(platform.invitation_only?).to be(true)
  end
end
