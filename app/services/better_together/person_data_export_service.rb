# frozen_string_literal: true

module BetterTogether
  # Builds a portable, non-destructive account export payload for a person.
  # rubocop:disable Metrics/ClassLength
  class PersonDataExportService
    def initialize(person:)
      @person = person
    end

    def call
      {
        exported_at: Time.current.iso8601,
        person: person_attributes,
        memberships: memberships,
        agreements: agreements,
        blocks: blocks,
        reports: reports,
        conversations: conversations,
        events: events,
        integrations: integrations,
        seeds: seeds
      }
    end

    private

    attr_reader :person

    def person_attributes
      person.slice(
        :id,
        :identifier,
        :name,
        :description,
        :privacy,
        :preferences,
        :notification_preferences,
        :email
      ).merge(
        created_at: person.created_at&.iso8601,
        updated_at: person.updated_at&.iso8601
      )
    end

    def memberships
      {
        platforms: serialize_platform_memberships,
        communities: serialize_community_memberships
      }
    end

    def agreements
      person.agreement_participants.includes(:agreement).map do |participant|
        serialize_agreement_participant(participant)
      end
    end

    def blocks
      {
        blocked_people: serialize_blocked_people,
        blocked_by: serialize_blockers
      }
    end

    def reports
      {
        reports_made: serialize_reports_made,
        reports_received: serialize_reports_received
      }
    end

    def conversations
      {
        participated: serialize_participated_conversations,
        created: []
      }
    end

    def events
      {
        attendances: serialize_event_attendances,
        invitations: serialize_event_invitations
      }
    end

    def integrations
      person.person_platform_integrations.map do |integration|
        {
          id: integration.id,
          provider: integration.provider,
          platform_id: integration.platform_id,
          created_at: integration.created_at&.iso8601,
          updated_at: integration.updated_at&.iso8601
        }
      end
    end

    def seeds
      BetterTogether::Seed.personal_exports_for(person).latest_first.map do |seed|
        {
          id: seed.id,
          identifier: seed.identifier,
          created_at: seed.created_at&.iso8601,
          seeded_at: seed.seeded_at&.iso8601,
          description: seed.description
        }
      end
    end

    def serialize_platform_memberships
      person.person_platform_memberships.includes(:joinable, :role).map do |membership|
        {
          id: membership.id,
          status: membership.status,
          platform_id: membership.joinable_id,
          platform_name: membership.joinable&.name,
          role: membership.role&.identifier,
          created_at: membership.created_at&.iso8601
        }
      end
    end

    def serialize_community_memberships
      person.person_community_memberships.includes(:joinable, :role).map do |membership|
        {
          id: membership.id,
          status: membership.status,
          community_id: membership.joinable_id,
          community_name: membership.joinable&.name,
          role: membership.role&.identifier,
          created_at: membership.created_at&.iso8601
        }
      end
    end

    def serialize_agreement_participant(participant)
      {
        id: participant.id,
        agreement_id: participant.agreement_id,
        agreement_identifier: participant.agreement&.identifier,
        agreement_name: participant.agreement&.name,
        accepted_at: participant.accepted_at&.iso8601,
        created_at: participant.created_at&.iso8601,
        updated_at: participant.updated_at&.iso8601
      }
    end

    def serialize_blocked_people
      person.person_blocks.includes(:blocked).map do |block|
        {
          id: block.id,
          blocked_person_id: block.blocked_id,
          blocked_person_name: block.blocked&.name,
          created_at: block.created_at&.iso8601
        }
      end
    end

    def serialize_blockers
      person.blocked_by_person_blocks.includes(:blocker).map do |block|
        {
          id: block.id,
          blocker_person_id: block.blocker_id,
          blocker_person_name: block.blocker&.name,
          created_at: block.created_at&.iso8601
        }
      end
    end

    def serialize_reports_made
      person.reports_made.map do |report|
        {
          id: report.id,
          status: report.status,
          reportable_type: report.reportable_type,
          reportable_id: report.reportable_id,
          created_at: report.created_at&.iso8601
        }
      end
    end

    def serialize_reports_received
      person.reports_received.map do |report|
        {
          id: report.id,
          status: report.status,
          reporter_id: report.reporter_id,
          created_at: report.created_at&.iso8601
        }
      end
    end

    def serialize_participated_conversations
      person.conversation_participants.includes(:conversation).map do |participant|
        conversation = participant.conversation
        {
          conversation_id: conversation&.id,
          title: conversation&.title,
          joined_at: participant.created_at&.iso8601,
          updated_at: participant.updated_at&.iso8601
        }
      end
    end

    def serialize_event_attendances
      person.event_attendances.map do |attendance|
        {
          id: attendance.id,
          event_id: attendance.event_id,
          created_at: attendance.created_at&.iso8601,
          updated_at: attendance.updated_at&.iso8601
        }
      end
    end

    def serialize_event_invitations
      person.event_invitations.map do |invitation|
        {
          id: invitation.id,
          invitable_id: invitation.invitable_id,
          status: invitation.status,
          created_at: invitation.created_at&.iso8601
        }
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
