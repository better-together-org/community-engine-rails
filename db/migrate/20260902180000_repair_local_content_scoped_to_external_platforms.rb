# frozen_string_literal: true

# Idempotent repair for the 0.11.0 platform-scoping backfills.
#
# 20260321000003_backfill_content_platform_id and the 20260605xxx /
# 20260606xxx / 20260616xxx phase series each resolve their target platform
# by reading "the row WHERE host = TRUE" at migration time. During the
# federation / multi-tenant bootstrap the host flag can move between platform
# rows: a freshly-seeded "community-engine" platform is briefly host = TRUE
# before the real host platform is created and the seed row is demoted to
# external = TRUE. Content stamped in that window ends up scoped to a
# platform that is now external = TRUE, and PlatformRecordPolicy::Scope then
# hides it from every request. On a host app this silently replaces the
# homepage with the generic Community Engine page and 404s the other static
# pages (seen on newfoundlandlabrador.online: 11 pages incl. the homepage).
#
# A platform with external = TRUE is a remote federation peer. The only rows
# that may legitimately be scoped to it are *mirrored* copies of that peer's
# content (source_id IS NOT NULL). Any locally-authored row (source_id IS
# NULL) scoped to an external platform is corruption from the above and is
# reassigned here to the host platform. Tables without a source_id column
# (navigation) are never independently federated, so every row of theirs on
# an external platform is reassigned. Content blocks are realigned to follow
# their owning page. Pages/posts/events whose community itself lives on an
# external platform are pointed back at the host platform's community.
#
# Idempotent: every UPDATE's WHERE clause is empty on a second run. On a
# correctly-scoped instance (no external platforms, or nothing misfiled)
# this is a no-op. Rows that cannot be moved without colliding with an
# existing (identifier, host_platform_id) row are left in place and
# reported for manual review rather than raising. `down` is a deliberate
# no-op: the pre-repair state was the defect.
class RepairLocalContentScopedToExternalPlatforms < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  PROVENANCED_TABLES = %w[
    better_together_pages
    better_together_posts
    better_together_events
  ].freeze

  NAVIGATION_TABLES = %w[
    better_together_navigation_areas
    better_together_navigation_items
  ].freeze

  def up
    host_row = execute(
      'SELECT id, community_id FROM better_together_platforms WHERE host = TRUE LIMIT 1'
    ).first
    return unless host_row

    @host_platform_id = host_row.fetch('id')
    @host_community_id = host_row['community_id']
    @external_list = external_platform_id_list
    return if @external_list.nil?

    PROVENANCED_TABLES.each { |table| reassign(table, source_aware: true) }
    NAVIGATION_TABLES.each  { |table| reassign(table, source_aware: false) }

    realign_content_blocks_to_owning_pages
    reassign_orphan_content_blocks
    realign_community_ids_off_external_platforms
  end

  def down
    say 'RepairLocalContentScopedToExternalPlatforms is a data repair; nothing to reverse.'
  end

  private

  def external_platform_id_list
    ids = execute('SELECT id FROM better_together_platforms WHERE external = TRUE').map { |row| row.fetch('id') }
    return if ids.empty?

    ids.map { |id| quote(id) }.join(', ')
  end

  def col?(table, name)
    column_exists?(table, name)
  end

  def touch(table)
    col?(table, :updated_at) ? ', updated_at = NOW()' : ''
  end

  def reassign(table, source_aware:)
    return unless table_exists?(table) && col?(table, :platform_id)

    source_clause = source_aware && col?(table, :source_id) ? 'AND t.source_id IS NULL' : ''
    guard_clause  = col?(table, :identifier) ? collision_guard(table) : ''

    result = execute(<<~SQL)
      UPDATE #{table} t
      SET    platform_id = #{quote(@host_platform_id)}#{touch(table)}
      WHERE  t.platform_id IN (#{@external_list})
        #{source_clause}
        #{guard_clause}
    SQL

    say "#{table}: reassigned #{result.cmd_tuples} row(s) from an external platform to the host platform"
    report_unmoved(table, source_clause) unless guard_clause.empty?
  end

  # Only skip a move when the row has a non-blank identifier that already
  # exists on the host platform. Blank / NULL identifiers never trip the
  # partial unique index's identifier arm.
  def collision_guard(table)
    <<~SQL.chomp
      AND (
        t.identifier IS NULL OR t.identifier = ''
        OR NOT EXISTS (
          SELECT 1 FROM #{table} existing
          WHERE existing.identifier = t.identifier
            AND existing.platform_id = #{quote(@host_platform_id)}
            AND existing.id <> t.id
        )
      )
    SQL
  end

  def report_unmoved(table, source_clause)
    remaining = execute(
      "SELECT COUNT(*) AS count FROM #{table} t WHERE t.platform_id IN (#{@external_list}) #{source_clause}"
    ).first['count'].to_i
    return unless remaining.positive?

    say "WARNING: #{table}: #{remaining} row(s) still scoped to an external platform because their " \
        'identifier already exists on the host platform. Resolve the duplicate identifiers manually.'
  end

  def realign_content_blocks_to_owning_pages
    return unless content_block_page_tables_ready?

    result = execute(<<~SQL)
      UPDATE better_together_content_blocks block
      SET    platform_id = page.platform_id, updated_at = NOW()
      FROM   better_together_content_page_blocks page_block
      JOIN   better_together_pages page ON page.id = page_block.page_id
      WHERE  page_block.block_id = block.id
        AND  page.platform_id IS NOT NULL
        AND  block.platform_id IS DISTINCT FROM page.platform_id
    SQL

    say "better_together_content_blocks: realigned #{result.cmd_tuples} block(s) to their owning page's platform"
  end

  # Blocks not attached to any page cannot be realigned; move the ones
  # stranded on an external platform to the host platform.
  def reassign_orphan_content_blocks
    return unless content_block_page_tables_ready?

    result = execute(<<~SQL)
      UPDATE better_together_content_blocks block
      SET    platform_id = #{quote(@host_platform_id)}, updated_at = NOW()
      WHERE  block.platform_id IN (#{@external_list})
        AND  NOT EXISTS (
               SELECT 1 FROM better_together_content_page_blocks page_block
               WHERE page_block.block_id = block.id
             )
        AND  (
               block.identifier IS NULL OR block.identifier = ''
               OR NOT EXISTS (
                 SELECT 1 FROM better_together_content_blocks existing
                 WHERE existing.identifier = block.identifier
                   AND existing.platform_id = #{quote(@host_platform_id)}
                   AND existing.id <> block.id
               )
             )
    SQL

    say "better_together_content_blocks: reassigned #{result.cmd_tuples} unattached block(s) " \
        'from an external platform to the host platform'
  end

  # A locally-authored page/post/event whose community itself lives on an
  # external platform was mis-scoped by the same bootstrap window. Point it
  # back at the host platform's community. Requires a communities.platform_id
  # column (added by 20260607006000) and a resolvable host community.
  def realign_community_ids_off_external_platforms
    return if @host_community_id.blank?
    return unless table_exists?(:better_together_communities) && col?(:better_together_communities, :platform_id)

    PROVENANCED_TABLES.each { |table| realign_table_community(table) }
  end

  def realign_table_community(table)
    return unless table_exists?(table) && col?(table, :community_id)

    source_clause = col?(table, :source_id) ? 'AND t.source_id IS NULL' : ''

    result = execute(<<~SQL)
      UPDATE #{table} t
      SET    community_id = #{quote(@host_community_id)}#{touch(table)}
      FROM   better_together_communities c
      WHERE  t.community_id = c.id
        AND  c.platform_id IN (#{@external_list})
        #{source_clause}
    SQL

    say "#{table}: realigned #{result.cmd_tuples} row(s) whose community sat on an external platform"
  end

  def content_block_page_tables_ready?
    table_exists?(:better_together_content_blocks) &&
      table_exists?(:better_together_content_page_blocks) &&
      table_exists?(:better_together_pages) &&
      col?(:better_together_content_blocks, :platform_id)
  end
end
