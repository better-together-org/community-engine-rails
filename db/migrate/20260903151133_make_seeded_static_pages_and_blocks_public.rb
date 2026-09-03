# frozen_string_literal: true

# Page#privacy and Content::Block#privacy both default to 'private', and nothing
# syncs a block's privacy from its page. The built-in informational pages seeded
# by NavigationBuilder / AgreementBuilder (home, about, FAQ, the legal pages,
# contributor agreements) were therefore created private, with private blocks.
#
# Pre-#1778 they rendered anyway because the page renderer did not gate blocks by
# privacy. #1778 added that gate (policy_scope(page.content_blocks)), so a guest
# now sees these pages render empty. This aligns the seeded pages -- and every
# content block placed on them -- to the public visibility they have always been
# presented with.
#
# Page-scoped by slug (the same set NavigationBuilder / AgreementBuilder now seed
# with `privacy: 'public'` -- listed here so the migration stays self-contained).
# The deliberately-private host/admin pages are not in the list and are
# untouched. Raw SQL so the publishing-agreement model callback is not invoked.
# Idempotent (only rows not already public). `down` is a no-op -- restoring
# private would re-hide the pages.
class MakeSeededStaticPagesAndBlocksPublic < ActiveRecord::Migration[7.2]
  SEEDED_SLUGS = %w[
    home
    about
    better-together
    better-together/community-engine
    faq
    privacy-policy
    terms-of-service
    code-of-conduct
    accessibility
    cookie-policy
    contact
    subprocessors
    code-contributor-agreement
    content-contributor-agreement
  ].freeze

  REQUIRED_COLUMNS = {
    better_together_pages: %i[privacy],
    better_together_content_blocks: %i[privacy visible],
    better_together_content_page_blocks: %i[block_id page_id],
    mobility_string_translations: %i[translatable_type translatable_id key value]
  }.freeze

  def up
    return unless schema_ready?

    slug_list = SEEDED_SLUGS.map { |slug| quote(slug) }.join(', ')
    seeded_page_ids = <<~SQL.squish
      SELECT translatable_id
      FROM   mobility_string_translations
      WHERE  translatable_type = 'BetterTogether::Page'
        AND  key = 'slug'
        AND  value IN (#{slug_list})
    SQL

    pages = execute(<<~SQL)
      UPDATE better_together_pages
      SET    privacy = 'public', updated_at = NOW()
      WHERE  privacy <> 'public'
        AND  id IN (#{seeded_page_ids})
    SQL
    say "seeded static pages made public: #{pages.cmd_tuples}"

    blocks = execute(<<~SQL)
      UPDATE better_together_content_blocks
      SET    privacy = 'public', visible = TRUE, updated_at = NOW()
      WHERE  (privacy <> 'public' OR visible = FALSE)
        AND  id IN (
               SELECT pb.block_id
               FROM   better_together_content_page_blocks pb
               WHERE  pb.page_id IN (#{seeded_page_ids})
             )
    SQL
    say "content blocks on seeded static pages made public/visible: #{blocks.cmd_tuples}"
  end

  def down
    say 'MakeSeededStaticPagesAndBlocksPublic is not reversible; restoring ' \
        'private would re-hide the built-in legal/info pages from guests.'
  end

  private

  def schema_ready?
    REQUIRED_COLUMNS.all? do |table, columns|
      table_exists?(table) && columns.all? { |column| column_exists?(table, column) }
    end
  end
end
