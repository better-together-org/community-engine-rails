# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Makes the invoice or receipt of an order once for each state it is in, and keeps it: the PDF becomes a private
      # Upload (created by the buyer, so the Upload's own download serves them) joined to the order by an OrderDocument.
      # Asking again while the figures are the same returns the stored one; after a payment or refund the figures differ,
      # so a new one is made and the old one is marked superseded (and kept).
      #
      #   Orders::GenerateDocument.call(order, kind: :receipt)   # => Billing::OrderDocument
      class GenerateDocument
        def self.call(...) = new(...).call

        def initialize(order, kind: nil, locale: nil)
          @order = order
          @locale = (locale || order.locale_for_documents).to_sym
          @document = Document.new(order, kind:, locale: @locale)
        end

        def call
          existing_document || OrderDocument.transaction { store }
        rescue ActiveRecord::RecordNotUnique
          # A concurrent delivery stored the current document first (unique current-document index): use theirs.
          existing_document || raise
        end

        private

        attr_reader :order, :document

        def existing_document = order.documents.current.of_kind(document.kind).find_by(fingerprint:)

        def store # rubocop:disable Metrics/AbcSize
          pdf = document.to_pdf
          upload = create_upload(pdf)
          supersede_current
          order.documents.create!(upload:, platform: order.platform, kind: document.kind.to_s, fingerprint:,
                                  time_zone: document.time_zone, generated_at: document.generated_at).tap { |made| made.fresh_pdf = pdf }
        end

        def supersede_current
          order.documents.current.of_kind(document.kind).update_all(superseded_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
        end

        def create_upload(pdf)
          upload = Upload.new(platform: order.platform, creator: order.buyer, privacy: 'private', name: document.filename)
          upload.file.attach(io: StringIO.new(pdf), filename: document.filename, content_type: 'application/pdf')
          upload.save!
          upload
        end

        # What the document says, not when it was made: the same order in the same state gives the same print.
        def fingerprint = @fingerprint ||= Digest::SHA256.hexdigest(print.to_json)

        def print # rubocop:disable Metrics/AbcSize
          summary = document.summary
          [document.kind, @locale, order.number, order.status, order.net_paid_cents, order.refunded_cents,
           summary.total_cents, summary.tax_cents, summary.lines.map(&:to_h), summary.registrations.map(&:to_h)]
        end
      end
    end
  end
end
