# frozen_string_literal: true

require 'digest'

module BetterTogether
  module ContentSecurity
    # Builds shared-contract intake payloads for inbound mail and holds routing unless screening passes.
    class MailScreeningService
      Result = Struct.new(:allow_routing?, :screening_state, :screening_verdict, keyword_init: true)

      PASSABLE_VERDICTS = %w[clean monitor].freeze
      VERDICT_PRECEDENCE = {
        'clean' => 0,
        'monitor' => 1,
        'review_required' => 2,
        'restricted' => 3,
        'quarantined' => 4,
        'blocked' => 5
      }.freeze

      def initialize(inbound_email:, mail:, resolution:, sender:, body_plain:, scanner_runner: nil)
        @inbound_email = inbound_email
        @mail = mail
        @resolution = resolution
        @sender = sender
        @body_plain = body_plain
        @scanner_runner = scanner_runner || BetterTogether::ContentSecurity::OrchestratorRunner.new
      end

      def screen!(message)
        results = screening_payloads(message).map { |payload| @scanner_runner.call(payload) }
        verdict = aggregate_verdict(results)
        screening_state = PASSABLE_VERDICTS.include?(verdict) ? 'passed' : 'held'

        message.update!(
          screening_state:,
          screening_verdict: verdict,
          content_screening_summary: summary_for(results, verdict),
          content_security_records: results.flat_map { |result| Array(result['records']) }
        )

        Result.new(
          allow_routing?: screening_state == 'passed',
          screening_state:,
          screening_verdict: verdict
        )
      rescue BetterTogether::ContentSecurity::OrchestratorRunner::Error => e
        message.update!(
          screening_state: 'error',
          screening_verdict: 'review_required',
          content_screening_summary: e.message,
          content_security_records: []
        )

        Result.new(
          allow_routing?: false,
          screening_state: 'error',
          screening_verdict: 'review_required'
        )
      end

      private

      def screening_payloads(message)
        [message_payload(message), *attachment_payloads(message)]
      end

      def message_payload(message)
        raw_source = @mail.encoded.to_s

        {
          tenant: tenant_payload,
          source: {
            surface: 'mail',
            connector: 'better_together_action_mailbox',
            source_ref: "action_mailbox:#{@inbound_email.id}:body",
            ingress_method: 'email'
          },
          object: {
            canonical_ref: "better_together/inbound_email_message/#{message.id}/body",
            content_kind: 'email',
            mime_type: @mail.mime_type.to_s.presence || 'message/rfc822',
            filename: "#{message.message_id.presence || @inbound_email.message_id || @inbound_email.id}.eml",
            size_bytes: raw_source.bytesize,
            storage_backend: 'mail_store',
            primary_digest: digest_for(raw_source)
          },
          content_text: [message_metadata_text, @body_plain, attachment_manifest_text].compact_blank.join("\n\n"),
          trigger_event: 'ce_inbound_email_received',
          privacy: privacy_payload,
          visibility: visibility_payload,
          ai_ingestion: ai_ingestion_payload
        }
      end

      def attachment_payloads(message)
        @mail.attachments.each_with_index.map do |attachment, index|
          raw_content = attachment.body.decoded.to_s
          filename = attachment.filename.to_s

          {
            tenant: tenant_payload,
            source: {
              surface: 'mail',
              connector: 'better_together_action_mailbox_attachment',
              source_ref: "action_mailbox:#{@inbound_email.id}:attachment:#{index}",
              ingress_method: 'email'
            },
            object: {
              canonical_ref: "better_together/inbound_email_message/#{message.id}/attachments/#{index}",
              content_kind: 'file',
              mime_type: attachment.mime_type.to_s.presence,
              filename: filename.presence || "attachment-#{index}",
              size_bytes: raw_content.bytesize,
              storage_backend: 'mail_store',
              primary_digest: digest_for(raw_content)
            },
            content_text: attachment_text_payload(attachment, raw_content),
            trigger_event: 'ce_inbound_email_received',
            privacy: privacy_payload,
            visibility: visibility_payload,
            ai_ingestion: ai_ingestion_payload
          }
        end
      end

      def tenant_payload
        if @resolution.platform.present?
          {
            tenant_key: @resolution.platform.identifier,
            tenant_type: 'ce_app',
            source_system: 'ce',
            source_instance: @resolution.recipient_domain
          }
        else
          {
            tenant_key: @resolution.recipient_domain.presence || 'unknown-mailbox',
            tenant_type: 'mailbox',
            source_system: 'mail',
            source_instance: 'ce_action_mailbox'
          }
        end
      end

      def privacy_payload
        {
          sensitivity_level: 'community_private',
          contains_personal_data: true,
          evidence_level: 'excerpt_only',
          retention_class: 'standard'
        }
      end

      def visibility_payload
        {
          human_status: 'pending_review',
          share_state: 'disabled',
          served_via_proxy: false
        }
      end

      def ai_ingestion_payload
        {
          eligibility: 'excluded',
          rationale: 'Inbound mail remains excluded from AI ingestion until screening and review are complete.'
        }
      end

      def message_metadata_text
        [
          "from: #{@sender.address}",
          "to: #{@resolution.recipient_address}",
          "subject: #{@mail.subject}",
          "message-id: #{@mail.message_id}"
        ].join("\n")
      end

      def attachment_manifest_text
        return if @mail.attachments.blank?

        manifest_lines = @mail.attachments.map.with_index do |attachment, index|
          "#{index + 1}. #{attachment.filename} (#{attachment.mime_type || 'application/octet-stream'})"
        end
        "attachments:\n#{manifest_lines.join("\n")}"
      end

      def attachment_text_payload(attachment, raw_content)
        return raw_content if text_attachment?(attachment)

        [
          "filename: #{attachment.filename}",
          "mime_type: #{attachment.mime_type}",
          'binary attachment content omitted from text payload'
        ].join("\n")
      end

      def text_attachment?(attachment)
        mime_type = attachment.mime_type.to_s
        mime_type.start_with?('text/') || mime_type.in?(%w[application/json application/xml text/xml])
      end

      def digest_for(value)
        {
          algorithm: 'sha256',
          value: Digest::SHA256.hexdigest(value.to_s)
        }
      end

      def aggregate_verdict(results)
        verdicts = results.map { |result| result.dig('content_item', 'aggregate_verdict').presence || 'review_required' }
        verdicts.max_by { |verdict| VERDICT_PRECEDENCE.fetch(verdict, VERDICT_PRECEDENCE['review_required']) }
      end

      def summary_for(results, verdict)
        finding_summaries = results.flat_map { |result| Array(result['findings']).map { |finding| finding['summary'] } }.compact
        return 'Content safety screening passed for inbound email and attachments.' if finding_summaries.blank? && PASSABLE_VERDICTS.include?(verdict)

        [verdict.humanize, *finding_summaries].join(': ')
      end
    end
  end
end
