# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Enrolls attachments that existed before a scanning surface was enabled.
    #
    # Enrollment normally runs on commit. Records attached before the surface was
    # turned on have no Item, and BlobAccessPolicy treats a missing Item as not
    # releasable, so those files cannot be served until they are enrolled and
    # scanned. Safe to re-run: AttachmentEnrollment only schedules a scan when an
    # Item is new or its blob changed.
    class AttachmentBackfill
      Summary = Struct.new(:enrolled, :skipped_surface_disabled, :models, keyword_init: true)

      class << self
        def call(dry_run: false)
          summary = Summary.new(enrolled: 0, skipped_surface_disabled: 0, models: [])
          return summary unless Configuration.enabled?

          scannable_models.each { |model| backfill_model(model, summary, dry_run) }
          summary
        end

        private

        def scannable_models
          Rails.application.eager_load!
          ActiveRecord::Base.descendants.select do |model|
            !model.abstract_class? && model.respond_to?(:scannable_attachments) && model.scannable_attachments.present?
          end
        end

        def backfill_model(model, summary, dry_run)
          model.scannable_attachments.each do |name, config|
            surface = config.fetch(:surface)
            unless Configuration.enabled_for_surface?(surface)
              summary.skipped_surface_disabled += 1
              next
            end

            summary.models << "#{model.name}##{name}"
            model.joins(:"#{name}_attachment").find_each do |record|
              summary.enrolled += 1
              next if dry_run

              AttachmentEnrollment.sync_attachment!(record:, attachment_name: name, surface:)
            end
          end
        end
      end
    end
  end
end
