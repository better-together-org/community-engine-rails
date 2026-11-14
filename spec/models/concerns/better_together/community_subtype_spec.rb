# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe CommunitySubtype do
    let(:subtype) do
      stub_const('CommunitySubtypeProbe', Module.new)
      klass = stub_const('CommunitySubtypeProbe::GuildCommunity', Class.new(BetterTogether::Community))
      klass.include(described_class)
      klass
    end

    after { BetterTogether::Resourceful.instance_variable_get(:@registered).delete('CommunitySubtypeProbe::GuildCommunity') }

    it 'registers the subtype as a resource type for roles and permissions', :aggregate_failures do
      expect(BetterTogether::Resourceful.allowed_resource_classes).not_to include(subtype.name)

      subtype

      expect(BetterTogether::Resourceful.allowed_resource_classes).to include(subtype.name)
      expect(build(:better_together_role, resource_type: subtype.name)).to be_valid
    end

    it 'behaves as a Community to routes and policies', :aggregate_failures do
      expect(subtype.model_name.to_s).to eq('BetterTogether::Community')
      expect(subtype.policy_class).to eq(BetterTogether::CommunityPolicy)
    end

    it 'defines a named policy in the subtype namespace for invitation authorization', :aggregate_failures do
      subtype

      expect(CommunitySubtypeProbe::GuildCommunityPolicy.superclass).to eq(BetterTogether::CommunityPolicy)
    end

    it 'names the role tab from the label, defaulting to the humanized class name' do
      expect(subtype.community_subtype_label).to eq('Guild Community')
    end

    it 'uses the community member role as the default member role' do
      role = BetterTogether::Role.find_by(identifier: 'community_member', resource_type: 'BetterTogether::Community') ||
             create(:better_together_role, :community_role, identifier: 'community_member')

      expect(subtype.new.default_member_role).to eq(role)
    end
  end
end
