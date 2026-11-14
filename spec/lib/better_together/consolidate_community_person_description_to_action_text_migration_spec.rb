# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260805120000_consolidate_community_person_description_to_action_text'
)

RSpec.describe 'Consolidate Community/Person description to ActionText migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration_class) { ConsolidateCommunityPersonDescriptionToActionText }
  let(:connection) { ActiveRecord::Base.connection }

  def insert_plain_description(record)
    connection.execute(<<~SQL)
      INSERT INTO mobility_text_translations
        (translatable_type, translatable_id, key, value, locale, created_at, updated_at)
      VALUES (
        #{connection.quote(record.class.name)},
        #{connection.quote(record.id)}::uuid,
        'description',
        #{connection.quote('Plain bootstrap description')},
        'en',
        now(),
        now()
      )
    SQL
  end

  def insert_description_html(record, body: 'Real bio from the edit form')
    connection.execute(<<~SQL)
      INSERT INTO action_text_rich_texts
        (name, body, record_type, record_id, locale, created_at, updated_at)
      VALUES (
        'description_html',
        #{connection.quote(body)},
        #{connection.quote(record.class.name)},
        #{connection.quote(record.id)}::uuid,
        'en',
        now(),
        now()
      )
    SQL
  end

  def description_row(record)
    connection.select_one(
      "SELECT body FROM action_text_rich_texts WHERE name = 'description' " \
      "AND record_type = #{connection.quote(record.class.name)} AND record_id = '#{record.id}'"
    )
  end

  it 'moves a Community with only a plain description into action_text_rich_texts' do
    community = create(:better_together_community)
    insert_plain_description(community)

    migration_class.migrate(:up)

    expect(description_row(community)['body']).to eq('Plain bootstrap description')
  end

  it 'prefers description_html over a plain description when both exist (Community)' do
    community = create(:better_together_community)
    insert_plain_description(community)
    insert_description_html(community)

    migration_class.migrate(:up)

    expect(description_row(community)['body']).to eq('Real bio from the edit form')
    expect(
      connection.select_value(
        "SELECT count(*) FROM action_text_rich_texts WHERE name = 'description_html' " \
        "AND record_type = #{connection.quote(community.class.name)} AND record_id = '#{community.id}'"
      )
    ).to eq(0)
  end

  it 'renames description_html to description for Person when there was no plain row' do
    person = create(:person)
    insert_description_html(person, body: "Person's real bio")

    migration_class.migrate(:up)

    expect(description_row(person)['body']).to eq("Person's real bio")
  end

  it 'is idempotent when re-run with nothing left to migrate' do
    expect { migration_class.migrate(:up) }.not_to raise_error
  end
end
