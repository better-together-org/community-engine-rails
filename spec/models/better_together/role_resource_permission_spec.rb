# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::RoleResourcePermission do
  subject(:rrp) { described_class.new(role: role, resource_permission: permission) }

  let(:role) { create(:better_together_role) }
  let(:permission) { create(:better_together_resource_permission) }

  describe 'validations' do
    it 'is valid with role and resource_permission' do
      expect(rrp).to be_valid
    end

    it 'requires role' do
      rrp.role = nil
      expect(rrp).not_to be_valid
    end

    it 'requires resource_permission' do
      rrp.resource_permission = nil
      expect(rrp).not_to be_valid
    end

    it 'enforces unique role_id + resource_permission_id pair' do
      described_class.create!(role: role, resource_permission: permission)
      expect(rrp).not_to be_valid
      expect(rrp.errors[:role_id]).to be_present
    end
  end

  describe '#to_s' do
    it 'includes role name and permission identifier' do
      rrp.save!
      result = rrp.to_s
      expect(result).to include(role.name)
      expect(result).to include(permission.identifier)
    end
  end
end
