# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260717140000_replace_posts_identifier_unique_index_with_platform_scoped'
)

RSpec.describe 'Posts identifier unique index migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { ReplacePostsIdentifierUniqueIndexWithPlatformScoped.new }
  let(:connection) { ActiveRecord::Base.connection }

  # No index-restoration cleanup: the migration is idempotent (guards on
  # index_exists? before touching anything), and the platform-scoped index it
  # produces is the desired permanent end state — the same state `db:migrate`
  # already established — not a temporary condition to revert. Row data
  # created in each example is rolled back automatically by the standard
  # per-example transaction wrapper.

  it 'replaces the global unique index with a platform-scoped partial index' do
    migration.change

    expect(connection.index_exists?(:better_together_posts, :identifier, unique: true)).to be(false)
    expect(connection.index_name_exists?(:better_together_posts, 'idx_bt_posts_on_identifier_platform_id')).to be(true)
  end

  it 'allows the same identifier at the DB level across two different platforms afterward' do
    migration.change

    platform_a = create(:better_together_platform, :public, host: false)
    platform_b = create(:better_together_platform, :public, host: false)
    post_a = create(:better_together_post, platform: platform_a)
    post_b = create(:better_together_post, platform: platform_b)

    # Bypass model/Mobility slug validation entirely — this migration only
    # controls the DB-level constraint on the plain `identifier` column, not
    # the separately-validated (and separately-scoped) Mobility `slug` field.
    connection.execute(
      "UPDATE better_together_posts SET identifier = 'shared-identifier' WHERE id = #{connection.quote(post_a.id)}"
    )

    expect do
      connection.execute(
        "UPDATE better_together_posts SET identifier = 'shared-identifier' WHERE id = #{connection.quote(post_b.id)}"
      )
    end.not_to raise_error
  end
end
