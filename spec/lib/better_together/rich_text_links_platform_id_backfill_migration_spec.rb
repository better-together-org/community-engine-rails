# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260717120100_backfill_platform_id_for_metrics_rich_text_links')

RSpec.describe 'Rich text links platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillPlatformIdForMetricsRichTextLinks.new }
  let(:connection) { ActiveRecord::Base.connection }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:sender) { create(:better_together_person) }

  around do |example|
    connection.change_column_null(:better_together_metrics_rich_text_links, :platform_id, true)
    example.run
    connection.change_column_null(:better_together_metrics_rich_text_links, :platform_id, false)
  end

  it "derives platform_id from rich_text_record's own platform when NULL" do
    federated_platform = create(:better_together_platform, :public, host: false)
    conversation = BetterTogether::Conversation.create!(
      creator: sender, platform: federated_platform, title: '', participant_ids: [sender.id]
    )
    message = BetterTogether::Message.create!(conversation: conversation, sender: sender,
                                              platform: federated_platform, content: 'hi there')
    rich_text = ActionText::RichText.find_by!(record_type: 'BetterTogether::Message', record_id: message.id,
                                              name: 'content')
    link = create(:content_link)
    rich_text_link = BetterTogether::Metrics::RichTextLink.create!(
      link: link, rich_text: rich_text, rich_text_record: message, position: 0
    )
    rich_text_link.update_column(:platform_id, nil)

    migration.up

    expect(rich_text_link.reload.platform_id).to eq(federated_platform.id)
  end

  it 'falls back to host platform when the owner type has no platform_id column' do
    host_platform
    conversation = BetterTogether::Conversation.create!(
      creator: sender, platform: host_platform, title: '', participant_ids: [sender.id]
    )
    message = BetterTogether::Message.create!(conversation: conversation, sender: sender,
                                              platform: host_platform, content: 'hi there')
    rich_text = ActionText::RichText.find_by!(record_type: 'BetterTogether::Message', record_id: message.id,
                                              name: 'content')
    link = create(:content_link)
    rich_text_link = BetterTogether::Metrics::RichTextLink.new(link: link, rich_text: rich_text, position: 0)
    # A real rich_text_id is required by the FK constraint; the owner type itself is
    # the thing under test here, so it's overridden to something unresolvable.
    rich_text_link.rich_text_record_type = 'SomeNonExistentType'
    rich_text_link.rich_text_record_id = SecureRandom.uuid
    rich_text_link.save!(validate: false)

    migration.up

    expect(rich_text_link.reload.platform_id).to eq(host_platform.id)
  end
end
