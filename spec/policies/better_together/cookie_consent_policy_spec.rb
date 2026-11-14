# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CookieConsentPolicy do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:other) { create(:better_together_user, :confirmed) }

  it 'lets a person change only their own consent', :aggregate_failures do
    expect(described_class.new(user, user.person)).to be_update
    expect(described_class.new(user, other.person)).not_to be_update
  end

  it 'denies guests and non-person records', :aggregate_failures do
    expect(described_class.new(nil, user.person)).not_to be_update
    expect(described_class.new(user, Object.new)).not_to be_update
  end
end
