# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FeedbackPolicy do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:agent) { user.person }
  let(:other_person) { create(:better_together_person) }

  it 'shows the feedback surface for a signed-in person on someone else record' do
    expect(described_class.new(user, other_person).show?).to be true
    expect(described_class.new(user, other_person).report?).to be true
  end

  it 'hides the feedback surface when the viewer is signed out' do
    expect(described_class.new(nil, other_person).show?).to be false
  end

  it 'hides the report action for self-owned content' do
    post = create(:better_together_post, author: agent)

    expect(described_class.new(user, post).report?).to be false
  end

  it 'keeps future public contribution actions disabled by default' do
    policy = described_class.new(user, other_person)

    expect(policy.contribute_feedback?).to be false
    expect(policy.contribute_response?).to be false
    expect(policy.publish_without_moderation?).to be false
  end
end
