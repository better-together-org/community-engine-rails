require 'rails_helper'

RSpec.describe ::BetterTogether::ApplicationMailer, type: :mailer do
  include ActionMailer::TestHelper

  describe 'default from address' do
    it 'is set correctly' do
      expect(BetterTogether::ApplicationMailer.default[:from]).to eq('info@bettertogethersolutions.com')
    end
  end
end
