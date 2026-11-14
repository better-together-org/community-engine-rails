# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OauthUser do
  it 'inherits from the configured user class' do
    expect(described_class.superclass).to eq(BetterTogether.user_class)
  end

  describe '#password_required?' do
    subject(:oauth_user) { described_class.new }

    it 'returns false when password key is present in attributes hash' do
      expect(oauth_user.password_required?(password: 'somepassword')).to be false
    end
  end
end
