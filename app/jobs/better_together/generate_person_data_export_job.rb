# frozen_string_literal: true

module BetterTogether
  # Generates and attaches a portable account-data export for a pending request.
  class GeneratePersonDataExportJob < ApplicationJob
    queue_as :default

    def perform(export_id)
      export = BetterTogether::PersonDataExport.find(export_id)
      export.mark_processing!

      payload = BetterTogether::PersonDataExportService.new(person: export.person).call
      export.export_file.attach(
        io: StringIO.new(JSON.pretty_generate(payload)),
        filename: export.filename,
        content_type: 'application/json'
      )
      export.mark_completed!
    rescue StandardError => e
      export&.mark_failed!(e.message)
      raise
    end
  end
end
