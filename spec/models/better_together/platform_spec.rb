# frozen_string_literal: true

# spec/models/better_together/platform_spec.rb

require 'rails_helper'

module BetterTogether
  RSpec.describe Platform, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:platform) { build(:better_together_platform) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(platform).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:community).class_name('BetterTogether::Community').optional }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:description) }
      it { is_expected.to validate_presence_of(:url) }
      it { is_expected.to validate_uniqueness_of(:url) }
      it { is_expected.to validate_presence_of(:time_zone) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:name) }
      it { is_expected.to respond_to(:description) }
      it { is_expected.to respond_to(:url) }
      it { is_expected.to respond_to(:host) }
      it { is_expected.to respond_to(:time_zone) }
      it { is_expected.to respond_to(:privacy) }
    end

    describe 'Methods' do # rubocop:todo Metrics/BlockLength
      describe '#to_s' do
        it 'returns the name' do
          expect(platform.to_s).to eq(platform.name)
        end
      end

      describe '#set_as_host' do
        context 'when there is no host platform' do
          before { BetterTogether::Platform.where(host: true).destroy_all }

          it 'sets the host attribute to true' do
            platform.set_as_host
            expect(platform.host).to be true
          end
        end

        context 'when a host platform already exists' do
          before { create(:better_together_platform, host: true) }

          it 'does not set the host attribute to true' do
            platform.set_as_host
            expect(platform.host).to be false
          end
        end
      end

      describe '#build_host_community' do
        context 'when platform is set as host' do
          before { platform.host = true }

          it 'builds a host community' do
            community = platform.build_host_community
            expect(community).to be_a(BetterTogether::Community)
            expect(community.host).to be true
          end
        end

        context 'when platform is not set as host' do
          it 'does not build a host community' do
            community = platform.build_host_community
            expect(community).to be_nil
          end
        end
      end
    end

    describe 'Callbacks' do
      describe '#single_host_record' do
        context 'when trying to set host while another host exists' do
          before { create(:better_together_platform, host: true) }

          it 'adds an error to the platform' do
            platform.host = true
            platform.valid?
            expect(platform.errors[:host]).to include('can only be set for one record')
          end
        end
      end
    end
  end
end
