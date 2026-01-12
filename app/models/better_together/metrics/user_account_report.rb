# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Generates aggregate reports on user account creation and confirmation
    # Queries existing User data directly - no event tracking needed
    # rubocop:disable Metrics/ClassLength
    class UserAccountReport < ApplicationRecord
      # Associations
      belongs_to :creator, class_name: 'BetterTogether::Person', foreign_key: 'creator_id', inverse_of: :user_account_reports, optional: true

      # Active Storage attachment for the generated file
      has_one_attached :report_file, dependent: :purge_later

      # Validations
      validates :filters, presence: true
      validates :file_format, presence: true, inclusion: { in: %w[csv] }

      # Default ordering
      default_scope { order(created_at: :desc) }

      # Class method to create and generate a report
      def self.create_and_generate!(creator:, from_date: nil, to_date: nil, file_format: 'csv')
        report = create!(
          filters: { from_date: from_date, to_date: to_date }.compact,
          file_format: file_format,
          creator: creator
        )
        report.generate!
        report
      end

      # Generate the report data
      def generate!
        self.report_data = build_report_data
        save!
        GenerateUserAccountReportJob.perform_later(id)
      end

      private

      def build_report_data
        date_range = parse_date_range

        {
          summary: build_summary(date_range),
          daily_stats: build_daily_stats(date_range),
          registration_sources: build_registration_sources(date_range),
          locale_breakdown: build_locale_breakdown(date_range),
          generated_at: Time.current.iso8601
        }
      end

      def parse_date_range
        from_date = filters['from_date']&.to_date || 30.days.ago.to_date
        to_date = filters['to_date']&.to_date || Date.current
        from_date.beginning_of_day..to_date.end_of_day
      end

      def build_summary(date_range = nil)
        date_range ||= parse_date_range
        users_scope = BetterTogether::User.where(created_at: date_range)

        total_created = users_scope.count
        total_confirmed = users_scope.where.not(confirmed_at: nil).count
        confirmation_rate = total_created.positive? ? (total_confirmed.to_f / total_created * 100).round(2) : 0.0

        {
          total_accounts_created: total_created,
          total_accounts_confirmed: total_confirmed,
          confirmation_rate: confirmation_rate,
          date_range: {
            from: date_range.begin.to_date.iso8601,
            to: date_range.end.to_date.iso8601
          }
        }
      end

      def build_daily_stats(date_range = nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        date_range ||= parse_date_range
        # Group by date for accounts created
        created_by_date = BetterTogether::User
                          .where(created_at: date_range)
                          .group_by_day(:created_at, time_zone: 'UTC')
                          .count

        # Group by date for accounts confirmed
        confirmed_by_date = BetterTogether::User
                            .where(confirmed_at: date_range)
                            .where.not(confirmed_at: nil)
                            .group_by_day(:confirmed_at, time_zone: 'UTC')
                            .count

        # Combine into daily stats - only include dates with activity
        dates_with_activity = (created_by_date.keys + confirmed_by_date.keys).uniq.sort
        dates_with_activity.filter_map do |date|
          created = created_by_date[date] || 0
          confirmed = confirmed_by_date[date] || 0

          # Skip dates where both created and confirmed are 0
          next if created.zero? && confirmed.zero?

          {
            date: date.iso8601,
            accounts_created: created,
            accounts_confirmed: confirmed,
            confirmation_rate: created.positive? ? (confirmed.to_f / created * 100).round(2) : 0.0
          }
        end
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build_registration_sources(date_range = nil)
        date_range ||= parse_date_range
        users_scope = BetterTogether::User.where(created_at: date_range)
        users = BetterTogether::User.arel_table
        invitations = BetterTogether::Invitation.arel_table

        # Get users created via accepted invitations
        invitation_users = users_scope
                           .joins(
                             users.join(invitations, Arel::Nodes::OuterJoin).on(
                               invitations[:invitee_email].eq(users[:email])
                             ).join_sources
                           )
                           .where(invitations[:status].eq('accepted'))
                           .distinct
                           .count

        # Get users created via OAuth
        identifications = BetterTogether::Identification.arel_table
        people = BetterTogether::Person.arel_table
        platform_integrations = BetterTogether::PersonPlatformIntegration.arel_table

        oauth_users = users_scope
                      .joins(
                        users.join(identifications, Arel::Nodes::OuterJoin).on(
                          identifications[:agent_id].eq(users[:id])
                          .and(identifications[:agent_type].eq('BetterTogether::User'))
                        ).join_sources
                      )
                      .joins(
                        identifications.join(people, Arel::Nodes::OuterJoin).on(
                          people[:id].eq(identifications[:identity_id])
                        ).join_sources
                      )
                      .joins(
                        people.join(platform_integrations, Arel::Nodes::OuterJoin).on(
                          platform_integrations[:person_id].eq(people[:id])
                        ).join_sources
                      )
                      .where(platform_integrations[:provider].not_eq(nil))
                      .distinct
                      .count

        total = users_scope.count
        open_registration = total - invitation_users - oauth_users

        {
          open_registration: open_registration,
          invitation: invitation_users,
          oauth: oauth_users,
          total: total
        }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build_locale_breakdown(date_range = nil)
        date_range ||= parse_date_range
        # Query locale from Person preferences JSONB column via Identifications
        users_scope = BetterTogether::User.where(created_at: date_range)
        users = BetterTogether::User.arel_table
        identifications = BetterTogether::Identification.arel_table
        people = BetterTogether::Person.arel_table

        locale_counts = users_scope
                        .joins(
                          users.join(identifications, Arel::Nodes::OuterJoin).on(
                            identifications[:agent_id].eq(users[:id])
                            .and(identifications[:agent_type].eq('BetterTogether::User'))
                          ).join_sources
                        )
                        .joins(
                          identifications.join(people, Arel::Nodes::OuterJoin).on(
                            people[:id].eq(identifications[:identity_id])
                            .and(identifications[:identity_type].eq('BetterTogether::Person'))
                          ).join_sources
                        )
                        .where(identifications[:active].eq(true))
                        .group("better_together_people.preferences->>'locale'")
                        .count

        total = users_scope.count

        # Format as percentages
        locale_counts.transform_values do |count|
          {
            count: count,
            percentage: total.positive? ? (count.to_f / total * 100).round(2) : 0.0
          }
        end.merge(total: total)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
    # rubocop:enable Metrics/ClassLength
  end
end
