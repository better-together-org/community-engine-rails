# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MentionPrefetch do
  let(:probe_class) do
    Class.new do
      include BetterTogether::MentionPrefetch

      attr_reader :user

      def initialize(user)
        @user = user
      end

      def policy_scope(scope)
        BetterTogether::PersonPolicy::Scope.new(user, scope).resolve
      end

      public :prefetch_mention_visibility
    end
  end

  let(:viewer_user) { create(:better_together_user, :confirmed) }
  let(:public_person) { create(:better_together_person, privacy: 'public') }
  let(:private_person) { create(:better_together_person, privacy: 'private') }
  let(:blocked_person) { create(:better_together_person, privacy: 'public') }
  let(:blocker_person) { create(:better_together_person, privacy: 'public') }

  def visible_ids_for(user, people)
    probe = probe_class.new(user)
    probe.prefetch_mention_visibility(people)
    probe.instance_variable_get(:@mention_visible_ids)
  end

  before do
    create(:person_block, blocker: viewer_user.person, blocked: blocked_person)
    create(:person_block, blocker: blocker_person, blocked: viewer_user.person)
  end

  it 'includes public people and the viewer', :aggregate_failures do
    ids = visible_ids_for(viewer_user, [public_person, viewer_user.person])

    expect(ids).to eq(Set[public_person.id, viewer_user.person.id])
  end

  it 'leaves out private people the viewer cannot see' do
    expect(visible_ids_for(viewer_user, [public_person, private_person])).not_to include(private_person.id)
  end

  it 'leaves out people the viewer blocked and people who blocked the viewer' do
    ids = visible_ids_for(viewer_user, [public_person, blocked_person, blocker_person])

    expect(ids).to eq(Set[public_person.id])
  end

  it 'limits an anonymous viewer to public people' do
    expect(visible_ids_for(nil, [public_person, private_person])).to eq(Set[public_person.id])
  end

  it 'ignores nil entries and duplicates' do
    expect(visible_ids_for(viewer_user, [nil, public_person, public_person])).to eq(Set[public_person.id])
  end
end
