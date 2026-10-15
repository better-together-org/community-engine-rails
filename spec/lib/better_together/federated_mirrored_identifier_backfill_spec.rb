# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260516193000_backfill_federated_mirrored_identifiers')

RSpec.describe 'Federated mirrored identifier backfill' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillFederatedMirroredIdentifiers.new }
  let(:source_platform) { create(:better_together_platform, :community_engine_peer) }
  let(:target_platform) { create(:better_together_platform, :public, identifier: 'local-platform') }

  it 'backfills mirrored identifiers and leaves native records unchanged' do
    create(
      :better_together_platform_connection,
      :active,
      source_platform:,
      target_platform:,
      content_sharing_policy: 'mirror_network_feed',
      share_posts: true,
      share_pages: true,
      share_events: true
    )

    native_post = create(:better_together_post, identifier: 'native-post', platform: target_platform)
    mirrored_post = create(:better_together_post, identifier: 'remote-post', platform: target_platform, source_id: 'legacy-post-42')
    mirrored_page = create(:better_together_page, identifier: 'remote-page', platform: target_platform, source_id: 'legacy-page-42')
    mirrored_event = create(:better_together_event, identifier: 'remote-event', platform: target_platform, source_id: 'legacy-event-42')

    old_post_slug = mirrored_post.slug

    migration.up

    expect(native_post.reload.identifier).to eq('native-post')
    expect(mirrored_post.reload.identifier).to eq("#{source_platform.identifier}--remote-post")
    expect(mirrored_page.reload.identifier).to eq("#{source_platform.identifier}--remote-page")
    expect(mirrored_event.reload.identifier).to eq("#{source_platform.identifier}--remote-event")
    # update_columns deliberately rewrites only `identifier` (see the migration), so the
    # translated slug is left alone rather than regenerated with validations/history.
    expect(mirrored_post.slug).to eq(old_post_slug)
  end

  it 'remains idempotent for mirrored records that are already namespaced' do
    create(
      :better_together_platform_connection,
      :active,
      source_platform:,
      target_platform:,
      content_sharing_policy: 'mirror_network_feed',
      share_posts: true
    )

    mirrored_post = create(
      :better_together_post,
      identifier: "#{source_platform.identifier}--remote-post",
      platform: target_platform,
      source_id: 'legacy-post-42'
    )

    migration.up
    expect(mirrored_post.reload.identifier).to eq("#{source_platform.identifier}--remote-post")

    migration.up
    expect(mirrored_post.reload.identifier).to eq("#{source_platform.identifier}--remote-post")
  end
end
