# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::GeneratePersonDataExportJob do
  it 'generates and attaches a json export file' do
    export = create(:better_together_person_data_export)

    described_class.perform_now(export.id)
    export.reload

    expect(export).to be_completed
    expect(export.export_file).to be_attached
    expect(export.export_file.download).to include(export.person.identifier)
  end
end
