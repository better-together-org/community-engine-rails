# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260330203000_add_acceptance_audit_fields_to_agreement_participants')

RSpec.describe 'Agreement participant acceptance audit fields NOT NULL guard' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { AddAcceptanceAuditFieldsToAgreementParticipants.new }
  let(:connection) { ActiveRecord::Base.connection }
  let(:audit_columns) do
    %i[acceptance_method agreement_identifier_snapshot agreement_title_snapshot
       agreement_updated_at_snapshot agreement_content_digest]
  end

  around do |example|
    audit_columns.each { |c| connection.change_column_null(:better_together_agreement_participants, c, true) }
    example.run
    audit_columns.each { |c| connection.change_column_null(:better_together_agreement_participants, c, false) }
  end

  it 'warns and skips the NOT NULL constraints rather than hard-failing on an orphaned participant' do
    participant = create(:better_together_agreement_participant)
    participant.update_columns(audit_columns.index_with { nil })

    expect { migration.send(:enforce_acceptance_audit_constraints) }.to output(/WARNING.*acceptance-audit/).to_stdout

    expect(
      connection.columns(:better_together_agreement_participants).find { |c| c.name == 'acceptance_method' }.null
    ).to be(true)
  end

  it 'enforces the NOT NULL constraints once every participant has its audit fields populated' do
    create(:better_together_agreement_participant)

    expect { migration.send(:enforce_acceptance_audit_constraints) }.not_to output(/WARNING/).to_stdout

    expect(
      connection.columns(:better_together_agreement_participants).find { |c| c.name == 'acceptance_method' }.null
    ).to be(false)
  end
end
