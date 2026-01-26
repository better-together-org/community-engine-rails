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
        permission = create(:resource_permission, resource_type: 'BetterTogether::Community')
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
        shared_position = rand(10_000_000..20_000_000)
        create(:resource_permission, resource_type: 'BetterTogether::Community', position: shared_position)
        duplicate = build(:resource_permission, resource_type: 'BetterTogether::Community', position: shared_position)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:position]).to be_present
      end

      it 'allows same position for different resource_types' do
        shared_position = rand(20_000_000..30_000_000)
        create(:resource_permission, resource_type: 'BetterTogether::Community', position: shared_position)
        different_type = build(:resource_permission, resource_type: 'BetterTogether::Platform', position: shared_position)

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
        expect(described_class::ACTIONS).to eq(%w[create read update delete list manage view download])
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
        permission = create(:resource_permission, resource_type: 'BetterTogether::Community')
        expect(permission.to_s).to eq(permission.identifier)
      end
    end

    describe 'scopes' do
      describe '.positioned' do
        it 'orders by resource_type and position' do
          # Use large random position numbers to avoid conflicts across parallel workers
          base_position = rand(30_000_000..40_000_000)
          perm1 = create(:resource_permission, resource_type: 'BetterTogether::Platform', position: base_position)
          perm2 = create(:resource_permission, resource_type: 'BetterTogether::Community', position: base_position)
          perm3 = create(:resource_permission, resource_type: 'BetterTogether::Community', position: base_position + 1)

          positioned = described_class.where(id: [perm1.id, perm2.id, perm3.id]).positioned

          # Should order by resource_type first (alphabetically), then position
          expect(positioned.to_a).to eq([perm2, perm3, perm1])
        end
      end
    end
  end
end
