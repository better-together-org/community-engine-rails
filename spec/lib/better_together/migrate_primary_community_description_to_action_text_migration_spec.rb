# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260805110000_migrate_primary_community_description_to_action_text'
)

RSpec.describe 'Migrate PrimaryCommunity description to ActionText migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration_class) { MigratePrimaryCommunityDescriptionToActionText }
  let(:connection) { ActiveRecord::Base.connection }

  it 'moves a plain-text description row into action_text_rich_texts and removes the source row' do
    country = create(:geography_country)

    connection.execute(<<~SQL)
      INSERT INTO mobility_text_translations
        (translatable_type, translatable_id, key, value, locale, created_at, updated_at)
      VALUES (
        #{connection.quote(country.class.name)},
        #{connection.quote(country.id)}::uuid,
        'description',
        #{connection.quote('A large, cold country')},
        'en',
        now(),
        now()
      )
    SQL

    migration_class.migrate(:up)

    expect(
      connection.select_value(
        "SELECT count(*) FROM mobility_text_translations WHERE key = 'description' " \
        "AND translatable_type = #{connection.quote(country.class.name)} AND translatable_id = '#{country.id}'"
      )
    ).to eq(0)

    country.reload
    expect(country.description.to_plain_text).to eq('A large, cold country')
  end

  it 'HTML-escapes the plain text so special characters round-trip correctly' do
    country = create(:geography_country)

    connection.execute(<<~SQL)
      INSERT INTO mobility_text_translations
        (translatable_type, translatable_id, key, value, locale, created_at, updated_at)
      VALUES (
        #{connection.quote(country.class.name)},
        #{connection.quote(country.id)}::uuid,
        'description',
        #{connection.quote('Trade & commerce < tourism')},
        'en',
        now(),
        now()
      )
    SQL

    migration_class.migrate(:up)

    country.reload
    expect(country.description.to_plain_text).to eq('Trade & commerce < tourism')
  end

  it 'is idempotent when re-run with nothing left to migrate' do
    expect { migration_class.migrate(:up) }.not_to raise_error
  end

  it 'reverts a migrated row back to mobility_text_translations on down' do
    country = create(:geography_country)

    connection.execute(<<~SQL)
      INSERT INTO mobility_text_translations
        (translatable_type, translatable_id, key, value, locale, created_at, updated_at)
      VALUES (
        #{connection.quote(country.class.name)},
        #{connection.quote(country.id)}::uuid,
        'description',
        #{connection.quote('A large, cold country')},
        'en',
        now(),
        now()
      )
    SQL

    migration_class.migrate(:up)
    migration_class.migrate(:down)

    row = connection.select_one(
      "SELECT value FROM mobility_text_translations WHERE key = 'description' " \
      "AND translatable_type = #{connection.quote(country.class.name)} AND translatable_id = '#{country.id}'"
    )
    expect(row['value']).to eq('A large, cold country')

    expect(
      connection.select_value(
        "SELECT count(*) FROM action_text_rich_texts WHERE name = 'description' " \
        "AND record_type = #{connection.quote(country.class.name)} AND record_id = '#{country.id}'"
      )
    ).to eq(0)
  end
end
