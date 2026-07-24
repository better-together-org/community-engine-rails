# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe 'Version constants' do
    it 'keeps VERSION aligned with the Zeitwerk-friendly Version namespace' do
      expect(BetterTogether::VERSION).to eq(BetterTogether::Version::STRING)
    end
  end
end
