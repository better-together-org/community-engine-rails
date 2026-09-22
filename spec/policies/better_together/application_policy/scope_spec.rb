# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationPolicy::Scope do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:scope) { BetterTogether::PersonCommunityMembership.all }

  describe 'scope options' do
    let(:scope_class) do
      Class.new(described_class) do
        def resolve
          options.fetch(:context)
        end
      end
    end

    it 'makes keyword options available to subclasses' do
      context = { community_id: 'community-123', person_id: user.person.id.to_s }

      expect(scope_class.new(user, scope, context: context).resolve).to eq(context)
    end

    it 'preserves invitation_token alongside keyword options' do
      resolved_scope = scope_class.new(user, scope, invitation_token: 'token-123', context: {}).tap do |policy_scope|
        expect(policy_scope.invitation_token).to eq('token-123')
      end

      expect(resolved_scope.resolve).to eq({})
    end
  end
end
