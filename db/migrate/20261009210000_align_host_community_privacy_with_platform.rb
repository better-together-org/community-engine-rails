# frozen_string_literal: true

# A platform's primary (host) community is created with the platform's privacy but nothing kept the two
# aligned afterwards, so an instance could end up with a public platform and a private host community
# (NL Venues did). CE's media gate answers 401 to anonymous visitors for media of a non-public record,
# so the site logo and cover image broke, and the privacy ceiling capped every page in the host community.
#
# This sets each host platform's community to the platform's privacy. Raw SQL: the platform's visibility
# was already governed when it was published, so the publishing-agreement validation is not invoked.
# Idempotent (only rows that differ); `down` is a no-op because restoring a private host community
# would re-break the host's branding for anonymous visitors.
class AlignHostCommunityPrivacyWithPlatform < ActiveRecord::Migration[7.2]
  REQUIRED_COLUMNS = {
    better_together_platforms: %i[privacy host community_id],
    better_together_communities: %i[privacy]
  }.freeze

  def up
    return unless schema_ready?

    result = execute(<<~SQL)
      UPDATE better_together_communities c
      SET    privacy = p.privacy, updated_at = NOW()
      FROM   better_together_platforms p
      WHERE  p.community_id = c.id
        AND  p.host = TRUE
        AND  c.privacy <> p.privacy
    SQL

    say "host communities aligned with their platform privacy: #{result.cmd_tuples}"
  end

  def down
    say 'AlignHostCommunityPrivacyWithPlatform is not reversible; ' \
        'restoring a private host community would re-break anonymous access to the host branding.'
  end

  private

  def schema_ready?
    REQUIRED_COLUMNS.all? do |table, columns|
      table_exists?(table) && columns.all? { |column| column_exists?(table, column) }
    end
  end
end
