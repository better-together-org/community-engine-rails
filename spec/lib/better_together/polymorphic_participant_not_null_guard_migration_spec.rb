# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260404203000_add_polymorphic_participant_to_agreement_participants')

RSpec.describe 'Agreement participant polymorphic participant NOT NULL guard' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { AddPolymorphicParticipantToAgreementParticipants.new }
  let(:connection) { ActiveRecord::Base.connection }

  around do |example|
    connection.change_column_null(:better_together_agreement_participants, :participant_type, true)
    connection.change_column_null(:better_together_agreement_participants, :participant_id, true)
    example.run
    connection.change_column_null(:better_together_agreement_participants, :participant_type, false)
    connection.change_column_null(:better_together_agreement_participants, :participant_id, false)
  end

  it 'warns and skips the NOT NULL constraint rather than hard-failing when a row has no person_id to derive from' do
    participant = create(:better_together_agreement_participant)
    participant.update_columns(participant_type: nil, participant_id: nil, person_id: nil)

    expect { migration.send(:enforce_participant_not_null!) }.to output(/WARNING.*NULL participant_type/).to_stdout

    expect(
      connection.columns(:better_together_agreement_participants).find { |c| c.name == 'participant_type' }.null
    ).to be(true)
  end

  it 'enforces the NOT NULL constraint once every row has a resolvable participant' do
    create(:better_together_agreement_participant)

    expect { migration.send(:enforce_participant_not_null!) }.not_to output(/WARNING/).to_stdout

    expect(
      connection.columns(:better_together_agreement_participants).find { |c| c.name == 'participant_type' }.null
    ).to be(false)
  end
end
