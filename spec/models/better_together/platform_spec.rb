# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Platform do
  describe 'validations' do
    subject(:platform) { build(:better_together_platform, url:) }

    context 'with valid http url' do
      let(:url) { 'http://example.org' }

      it { is_expected.to be_valid }
    end

    context 'with valid https url' do
      let(:url) { 'https://example.org' }

      it { is_expected.to be_valid }
    end

    context 'with invalid scheme' do
      let(:url) { 'javascript:alert(1)' }

      it 'is invalid' do # rubocop:todo RSpec/MultipleExpectations
        expect(platform).not_to be_valid
        expect(platform.errors[:url]).to be_present
      end
    end
  end
end
