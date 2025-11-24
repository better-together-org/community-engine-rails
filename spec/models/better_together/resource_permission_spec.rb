# frozen_string_literal: true

# spec/models/better_together/resource_permission_spec.rb

require 'rails_helper'

module BetterTogether
  RSpec.describe ResourcePermission do
    describe 'factory' do
      it 'creates a valid resource permission' do
        permission = build(:resource_permission, resource_type: 'BetterTogether::Community', position: 100)
        expect(permission).to be_valid
      end

      it 'generates derived target from resource_type' do
        permission = create(:resource_permission, resource_type: 'BetterTogether::Community', position: 101)
        expected_target = 'community'
        expect(permission.target).to eq(expected_target)
      end
    end

    describe 'associations' do
      it { is_expected.to have_many(:role_resource_permissions).class_name('BetterTogether::RoleResourcePermission').dependent(:destroy) }
      it { is_expected.to have_many(:roles).through(:role_resource_permissions) }
    end

    describe 'validations' do
      it { is_expected.to validate_inclusion_of(:action).in_array(described_class::ACTIONS) }

      it 'validates position uniqueness scoped to resource_type' do
        create(:resource_permission, resource_type: 'BetterTogether::Community', position: 200)
        duplicate = build(:resource_permission, resource_type: 'BetterTogether::Community', position: 200)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:position]).to be_present
      end

      it 'allows same position for different resource_types' do
        create(:resource_permission, resource_type: 'BetterTogether::Community', position: 300)
        different_type = build(:resource_permission, resource_type: 'BetterTogether::Platform', position: 300)

        expect(different_type).to be_valid
      end
    end

    describe 'concerns' do
      it 'includes Identifier concern' do
        expect(described_class.included_modules).to include(BetterTogether::Identifier)
      end

      it 'includes Positioned concern' do
        expect(described_class.included_modules).to include(BetterTogether::Positioned)
      end

      it 'includes Protected concern' do
        expect(described_class.included_modules).to include(BetterTogether::Protected)
      end

      it 'includes Resourceful concern' do
        expect(described_class.included_modules).to include(BetterTogether::Resourceful)
      end
    end

    describe 'actions constant' do
      it 'defines ACTIONS constant' do
        expect(described_class::ACTIONS).to eq(%w[create read update delete list manage view])
      end

      it 'accepts valid actions' do
        permission = build(:resource_permission, action: 'create', resource_type: 'BetterTogether::Community', position: 400)
        expect(permission).to be_valid
      end

      it 'rejects invalid actions' do
        permission = build(:resource_permission, action: 'invalid_action', resource_type: 'BetterTogether::Community', position: 401)
        expect(permission).not_to be_valid
        expect(permission.errors[:action]).to be_present
      end
    end

    describe '#position_scope' do
      it 'returns resource_type as position scope' do
        permission = build(:resource_permission, resource_type: 'BetterTogether::Community', position: 500)
        expect(permission.position_scope).to eq(:resource_type)
      end
    end

    describe '#to_s' do
      it 'returns the identifier' do
        permission = create(:resource_permission, resource_type: 'BetterTogether::Community', position: 600)
        expect(permission.to_s).to eq(permission.identifier)
      end
    end

    describe 'scopes' do
      describe '.positioned' do
        it 'orders by resource_type and position' do
          # Use high position numbers to avoid conflicts with seed data
          perm1 = create(:resource_permission, resource_type: 'BetterTogether::Platform', position: 1001)
          perm2 = create(:resource_permission, resource_type: 'BetterTogether::Community', position: 1001)
          perm3 = create(:resource_permission, resource_type: 'BetterTogether::Community', position: 1002)

          positioned = described_class.where('position >= 1001').positioned

          # Should order by resource_type first (alphabetically), then position
          expect(positioned.to_a).to eq([perm2, perm3, perm1])
        end
      end
    end
  end
end
