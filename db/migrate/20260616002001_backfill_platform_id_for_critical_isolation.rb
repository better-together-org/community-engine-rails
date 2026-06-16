# frozen_string_literal: true

# Phase 9 — Backfill critical isolation tables
class BackfillPlatformIdForCriticalIsolation < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  def up # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    # Step 1: Conversations from creator's platform membership
    if column_exists?(:better_together_conversations, :platform_id)
      execute <<~SQL
        UPDATE better_together_conversations c
        SET    platform_id = ppm.joinable_id
        FROM   better_together_people p
        JOIN   better_together_person_platform_memberships ppm
          ON   p.id = ppm.member_id
        WHERE  c.creator_id = p.id
          AND  c.platform_id IS NULL
          AND  ppm.joinable_id IS NOT NULL
        LIMIT  (SELECT count(*) FROM better_together_conversations WHERE platform_id IS NULL)
      SQL
    end

    # Step 2: Messages from conversation
    if column_exists?(:better_together_messages, :platform_id)
      execute <<~SQL
        UPDATE better_together_messages m
        SET    platform_id = c.platform_id
        FROM   better_together_conversations c
        WHERE  m.conversation_id = c.id
          AND  m.platform_id IS NULL
          AND  c.platform_id IS NOT NULL
      SQL
    end

    # Step 3: Activities from trackable objects (per-type backfill)
    if column_exists?(:better_together_activities, :platform_id)
      # Posts
      execute <<~SQL
        UPDATE better_together_activities a
        SET    platform_id = p.platform_id
        FROM   better_together_posts p
        WHERE  a.trackable_type = 'BetterTogether::Post'
          AND  a.trackable_id = p.id
          AND  a.platform_id IS NULL
          AND  p.platform_id IS NOT NULL
      SQL

      # Events
      execute <<~SQL
        UPDATE better_together_activities a
        SET    platform_id = e.platform_id
        FROM   better_together_events e
        WHERE  a.trackable_type = 'BetterTogether::Event'
          AND  a.trackable_id = e.id
          AND  a.platform_id IS NULL
          AND  e.platform_id IS NOT NULL
      SQL

      # Pages
      execute <<~SQL
        UPDATE better_together_activities a
        SET    platform_id = pa.platform_id
        FROM   better_together_pages pa
        WHERE  a.trackable_type = 'BetterTogether::Page'
          AND  a.trackable_id = pa.id
          AND  a.platform_id IS NULL
          AND  pa.platform_id IS NOT NULL
      SQL

      # Host platform fallback
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_activities
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 4: Reports from reportable's platform (Posts, Pages, Events, People, etc.)
    if column_exists?(:better_together_reports, :platform_id)
      # Posts
      execute <<~SQL
        UPDATE better_together_reports r
        SET    platform_id = p.platform_id
        FROM   better_together_posts p
        WHERE  r.reportable_type = 'BetterTogether::Post'
          AND  r.reportable_id = p.id
          AND  r.platform_id IS NULL
          AND  p.platform_id IS NOT NULL
      SQL

      # Pages
      execute <<~SQL
        UPDATE better_together_reports r
        SET    platform_id = pa.platform_id
        FROM   better_together_pages pa
        WHERE  r.reportable_type = 'BetterTogether::Page'
          AND  r.reportable_id = pa.id
          AND  r.platform_id IS NULL
          AND  pa.platform_id IS NOT NULL
      SQL

      # Events
      execute <<~SQL
        UPDATE better_together_reports r
        SET    platform_id = e.platform_id
        FROM   better_together_events e
        WHERE  r.reportable_type = 'BetterTogether::Event'
          AND  r.reportable_id = e.id
          AND  r.platform_id IS NULL
          AND  e.platform_id IS NOT NULL
      SQL

      # Host platform fallback
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_reports
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 5: PersonBlocks from blocker's platform
    if column_exists?(:better_together_person_blocks, :platform_id)
      execute <<~SQL
        UPDATE better_together_person_blocks pb
        SET    platform_id = ppm.joinable_id
        FROM   better_together_people blocker
        JOIN   better_together_person_platform_memberships ppm
          ON   blocker.id = ppm.member_id
        WHERE  pb.blocker_id = blocker.id
          AND  pb.platform_id IS NULL
          AND  ppm.joinable_id IS NOT NULL
      SQL
    end

    # Step 6: Invitations — derive from invitable
    if column_exists?(:better_together_invitations, :platform_id)
      # Platform invitations
      execute <<~SQL
        UPDATE better_together_invitations i
        SET    platform_id = i.invitable_id
        WHERE  i.invitable_type = 'BetterTogether::Platform'
          AND  i.platform_id IS NULL
          AND  i.invitable_id IS NOT NULL
      SQL

      # Community invitations -> platform via community.platform_id (after Phase 8)
      execute <<~SQL
        UPDATE better_together_invitations i
        SET    platform_id = c.platform_id
        FROM   better_together_communities c
        WHERE  i.invitable_type = 'BetterTogether::Community'
          AND  i.invitable_id = c.id
          AND  i.platform_id IS NULL
          AND  c.platform_id IS NOT NULL
      SQL

      # Host platform fallback
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_invitations
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 7: Authorships from authorable object's platform_id
    return unless column_exists?(:better_together_authorships, :platform_id)

    # Posts
    execute <<~SQL
      UPDATE better_together_authorships a
      SET    platform_id = p.platform_id
      FROM   better_together_posts p
      WHERE  a.authorable_type = 'BetterTogether::Post'
        AND  a.authorable_id = p.id
        AND  a.platform_id IS NULL
        AND  p.platform_id IS NOT NULL
    SQL

    # Pages
    execute <<~SQL
      UPDATE better_together_authorships a
      SET    platform_id = pa.platform_id
      FROM   better_together_pages pa
      WHERE  a.authorable_type = 'BetterTogether::Page'
        AND  a.authorable_id = pa.id
        AND  a.platform_id IS NULL
        AND  pa.platform_id IS NOT NULL
    SQL

    # Events
    execute <<~SQL
      UPDATE better_together_authorships a
      SET    platform_id = e.platform_id
      FROM   better_together_events e
      WHERE  a.authorable_type = 'BetterTogether::Event'
        AND  a.authorable_id = e.id
        AND  a.platform_id IS NULL
        AND  e.platform_id IS NOT NULL
    SQL

    # Host platform fallback
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    execute <<~SQL
      UPDATE better_together_authorships
      SET platform_id = #{quote(host_platform_id)}
      WHERE platform_id IS NULL
    SQL
  end

  def down
    %w[
      better_together_conversations
      better_together_messages
      better_together_activities
      better_together_reports
      better_together_person_blocks
      better_together_invitations
      better_together_authorships
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
