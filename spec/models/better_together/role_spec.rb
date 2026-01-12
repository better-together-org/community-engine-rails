# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Role do
    let(:role) { build(:better_together_role) }

    subject { role }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(role).to be_valid
      end

      describe 'traits' do
        describe ':platform_role' do
          subject(:platform_role) { create(:better_together_role, :platform_role) }

          it 'creates a role with Platform resource_type' do
            expect(platform_role.resource_type).to eq('BetterTogether::Platform')
          end
        end

        describe ':community_role' do
          subject(:community_role) { create(:better_together_role, :community_role) }

          it 'creates a role with Community resource_type' do
            expect(community_role.resource_type).to eq('BetterTogether::Community')
          end
        end

        describe 'combined traits' do
          it 'allows creating multiple platform roles' do
            role1 = create(:better_together_role, :platform_role)
            role2 = create(:better_together_role, :platform_role)

            expect(role1.resource_type).to eq('BetterTogether::Platform')
            expect(role2.resource_type).to eq('BetterTogether::Platform')
            expect(role1.id).not_to eq(role2.id)
          end

          it 'allows creating multiple community roles' do
            role1 = create(:better_together_role, :community_role)
            role2 = create(:better_together_role, :community_role)

            expect(role1.resource_type).to eq('BetterTogether::Community')
            expect(role2.resource_type).to eq('BetterTogether::Community')
            expect(role1.id).not_to eq(role2.id)
          end
        end
      end
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
    end

    # it_behaves_like 'a translatable record'
    it_behaves_like 'has_id'

    describe '.only_protected' do
      it { expect(described_class).to respond_to(:only_protected) }

      it 'scopes results to protected = true' do
        expect(described_class.only_protected.new).to have_attributes(protected: true)
      end
    end

    describe '#name' do
      it { is_expected.to respond_to(:name) }
    end

    describe '#to_s' do
      it { expect(role.to_s).to eq(role.name) }
    end

    describe '#description' do
      it { is_expected.to respond_to(:description) }
    end

    describe '#protected' do
      it { is_expected.to respond_to(:protected) }
    end

    describe '#position' do
      it { is_expected.to respond_to(:position) }

      it 'increments the max position when other roles exist' do # rubocop:todo RSpec/NoExpectationExample
        # max_position = ::BetterTogether::Role.maximum(:position)
        # max_position
        # role = create(:role)
        # expect(role.position).to eq(max_position + 1)
      end
    end

    describe '#resource_type' do
      it { is_expected.to respond_to(:resource_type) }
    end
  end
end
