# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationMailer do
  include ActionMailer::TestHelper

  describe 'default from address' do
    it 'is set correctly' do
      expect(described_class.default[:from]).to eq('Better Together Community <community@bettertogethersolutions.com>')
    end
  end
end
