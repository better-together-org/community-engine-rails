# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Geography::Maps', type: :request do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
  end

  describe 'GET /index' do
    it 'works' do
      expect(true).to be(true)
    end
  end
end
