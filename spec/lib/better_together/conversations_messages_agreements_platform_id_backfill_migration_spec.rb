# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260605002004_backfill_platform_id_for_conversations_messages_agreements'
)

RSpec.describe 'Conversations/messages/agreements platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillPlatformIdForConversationsMessagesAgreements.new }

  it "derives a conversation's platform_id from its creator's platform membership" do
    federated_platform = create(:better_together_platform, host: false)
    federated_person = create(:better_together_person)
    create(:better_together_person_platform_membership, joinable: federated_platform, member: federated_person)

    conversation = create(:better_together_conversation, creator: federated_person)
    conversation.update_column(:platform_id, nil)

    migration.up

    expect(conversation.reload.platform_id).to eq(federated_platform.id)
  end

  it 'falls back to the host platform when the creator has no platform membership' do
    conversation = create(:better_together_conversation)
    conversation.update_column(:platform_id, nil)

    migration.up

    expect(conversation.reload.platform_id).to eq(BetterTogether::Platform.find_by(host: true).id)
  end
end
