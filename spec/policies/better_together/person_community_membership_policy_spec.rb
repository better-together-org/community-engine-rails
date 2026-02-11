# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonCommunityMembershipPolicy, type: :policy do
  subject(:policy) { described_class.new(user, membership) }

  let(:platform) { create(:better_together_platform, host: true) }
  let(:community) { create(:better_together_community, platform:) }
  let(:user) { create(:user) }
  let(:person) { user.person }
  let(:other_person) { create(:better_together_person) }
  let(:membership) { create(:better_together_person_community_membership, joinable: community, member: person) }

  describe 'Scope' do
    subject(:scope) { described_class::Scope.new(user, BetterTogether::PersonCommunityMembership.all, **options) }

    let(:options) { {} }

    describe '#resolve' do
      context 'when user is not authenticated' do
        let(:user) { nil }

        it 'returns none' do
          expect(scope.resolve).to eq(BetterTogether::PersonCommunityMembership.none)
        end
      end

      context 'when context[:community_id] is present' do
        let(:options) { { context: { community_id: community.id } } }
        let!(:membership1) { create(:better_together_person_community_membership, joinable: community, member: person) }
        let!(:membership2) do
          create(:better_together_person_community_membership, joinable: community, member: other_person)
        end
        let!(:other_community_membership) do
          create(:better_together_person_community_membership, member: person)
        end

        context 'when user can manage memberships' do
          before do
            allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
              .with('update_community').and_return(true)
          end

          it 'returns memberships for the specified community' do
            results = scope.resolve
            expect(results).to include(membership1, membership2)
            expect(results).not_to include(other_community_membership)
          end
        end

        context 'when user cannot manage memberships' do
          before do
            allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?).and_return(false)
          end

          it 'returns none' do
            expect(scope.resolve).to eq(BetterTogether::PersonCommunityMembership.none)
          end
        end
      end

      context 'when context[:person_id] is present' do
        let(:options) { { context: { person_id: person.id.to_s } } }
        let!(:membership1) { create(:better_together_person_community_membership, joinable: community, member: person) }
        let!(:membership2) do
          create(:better_together_person_community_membership, joinable: community, member: other_person)
        end

        context 'when viewing own memberships' do
          it 'returns memberships for the specified person' do
            results = scope.resolve
            expect(results).to include(membership1)
            expect(results).not_to include(membership2)
          end
        end

        context 'when viewing another person\'s memberships as platform manager' do
          let(:options) { { context: { person_id: other_person.id.to_s } } }

          before do
            allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
              .with('manage_platform').and_return(true)
          end

          it 'returns memberships for the specified person' do
            results = scope.resolve
            expect(results).to include(membership2)
            expect(results).not_to include(membership1)
          end
        end

        context 'when viewing another person\'s memberships without permission' do
          let(:options) { { context: { person_id: other_person.id.to_s } } }

          before do
            allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?).and_return(false)
          end

          it 'returns none' do
            expect(scope.resolve).to eq(BetterTogether::PersonCommunityMembership.none)
          end
        end
      end

      context 'when no context is provided' do
        let!(:my_membership) { create(:better_together_person_community_membership, member: person) }
        let!(:other_membership) { create(:better_together_person_community_membership, member: other_person) }

        context 'when user can manage memberships' do
          before do
            allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
              .with('manage_platform').and_return(true)
          end

          it 'returns all memberships' do
            results = scope.resolve
            expect(results).to include(my_membership, other_membership)
          end
        end

        context 'when user cannot manage memberships' do
          before do
            allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?).and_return(false)
          end

          it 'returns only user\'s own memberships' do
            results = scope.resolve
            expect(results).to include(my_membership)
            expect(results).not_to include(other_membership)
          end
        end
      end
    end
  end

  describe '#index?' do
    context 'when user can manage memberships' do
      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
          .with('update_community').and_return(true)
      end

      it { is_expected.to permit_action(:index) }
    end

    context 'when user cannot manage memberships' do
      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?).and_return(false)
      end

      it { is_expected.to forbid_action(:index) }
    end
  end

  describe '#show?' do
    context 'when viewing own membership' do
      it { is_expected.to permit_action(:show) }
    end

    context 'when viewing another membership as platform manager' do
      let(:membership) { create(:better_together_person_community_membership, joinable: community, member: other_person) }

      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
          .with('manage_platform').and_return(true)
      end

      it { is_expected.to permit_action(:show) }
    end

    context 'when viewing another membership without permission' do
      let(:membership) { create(:better_together_person_community_membership, joinable: community, member: other_person) }

      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?).and_return(false)
      end

      it { is_expected.to forbid_action(:show) }
    end
  end

  describe '#create?' do
    context 'when user can manage memberships' do
      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
          .with('update_community').and_return(true)
      end

      it { is_expected.to permit_action(:create) }
    end

    context 'when user cannot manage memberships' do
      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?).and_return(false)
      end

      it { is_expected.to forbid_action(:create) }
    end
  end

  describe '#update?' do
    context 'when user can manage memberships' do
      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
          .with('update_community').and_return(true)
      end

      it { is_expected.to permit_action(:update) }
    end

    context 'when user cannot manage memberships' do
      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?).and_return(false)
      end

      it { is_expected.to forbid_action(:update) }
    end
  end

  describe '#destroy?' do
    context 'when destroying own membership' do
      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
          .with('update_community').and_return(true)
      end

      it { is_expected.to forbid_action(:destroy) }
    end

    context 'when destroying another membership as platform manager' do
      let(:membership) { create(:better_together_person_community_membership, joinable: community, member: other_person) }

      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
          .with('manage_platform').and_return(true)
        allow(other_person).to receive(:permitted_to?).with('manage_platform').and_return(false)
      end

      it { is_expected.to permit_action(:destroy) }
    end

    context 'when trying to destroy platform manager membership' do
      let(:membership) { create(:better_together_person_community_membership, joinable: community, member: other_person) }

      before do
        allow_any_instance_of(BetterTogether::Person).to receive(:permitted_to?)
          .with('manage_platform').and_return(true)
        allow(other_person).to receive(:permitted_to?).with('manage_platform').and_return(true)
      end

      it { is_expected.to forbid_action(:destroy) }
    end
  end
end
