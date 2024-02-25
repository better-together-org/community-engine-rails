# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Community, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:community) { build(:better_together_community) }
    let!(:existing_host_community) { create(:better_together_community, host: true) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(community).to be_valid
      end
    end

    it_behaves_like 'a friendly slugged record'
    it_behaves_like 'has_id'

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:creator).class_name('::BetterTogether::Person').optional }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:description) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:name) }
      it { is_expected.to respond_to(:description) }
      it { is_expected.to respond_to(:slug) }
      it { is_expected.to respond_to(:creator_id) }
      it { is_expected.to respond_to(:privacy) }
      it { is_expected.to respond_to(:host) }
    end

    describe 'Methods' do
      it { is_expected.to respond_to(:to_s) }
      it { is_expected.to respond_to(:set_as_host) }

      describe '#set_as_host' do
        context 'when there is no host community' do
          before { existing_host_community.destroy }

          it 'sets the host attribute to true' do
            community.set_as_host
            expect(community.host).to be true
          end
        end

        context 'when a host community already exists' do
          it 'does not set the host attribute to true' do
            community.set_as_host
            expect(community.host).to be false
          end
        end
      end
    end

    describe '#to_s' do
      it 'returns the name as a string representation' do
        expect(community.to_s).to eq(community.name)
      end
    end

    describe 'callbacks' do
      describe '#single_host_record' do
        it 'adds an error if host is set and another host community exists' do
          community.host = true
          community.valid?
          expect(community.errors[:host]).to include('can only be set for one community')
        end
      end
    end
  end
end
