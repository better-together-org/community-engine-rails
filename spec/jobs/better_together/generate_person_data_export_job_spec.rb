# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::GeneratePersonDataExportJob do
  it 'generates and attaches a json export file' do
    export = create(:better_together_person_data_export)

    described_class.perform_now(export.id)
    export.reload

    expect(export).to be_completed
    expect(export.export_file).to be_attached
    parsed = JSON.parse(export.export_file.download)
    root = parsed.fetch(BetterTogether::Seed::DEFAULT_ROOT_KEY)

    expect(root.dig('seed', 'origin', 'profile')).to eq('personal_export')
    expect(root.dig('payload', 'person', 'identifier')).to eq(export.person.identifier)
    expect(BetterTogether::Seed.personal_exports_for(export.person)).to exist
  end
end
