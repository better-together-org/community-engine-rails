# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationMailer, type: :mailer do
  include ActionMailer::TestHelper

  describe 'default from address' do
    it 'is set correctly' do
      # rubocop:todo Layout/LineLength
      expect(BetterTogether::ApplicationMailer.default[:from]).to eq('Better Together Community <community@bettertogethersolutions.com>')
      # rubocop:enable Layout/LineLength
    end
  end
end
