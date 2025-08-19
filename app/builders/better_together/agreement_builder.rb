# frozen_string_literal: true

# app/builders/better_together/agreement_builder.rb

module BetterTogether
  # Builder to seed initial agreements
  class AgreementBuilder < Builder
    class << self
      def seed_data
        build_privacy_policy
        build_terms_of_service
      end

      def clear_existing
        BetterTogether::AgreementParticipant.delete_all
        BetterTogether::AgreementTerm.delete_all
        BetterTogether::Agreement.delete_all
      end

      def build_privacy_policy # rubocop:todo Metrics/MethodLength
        agreement = BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') do |a|
          a.protected = true
          a.title = 'Privacy Policy'
          a.description = 'Summary of how we handle your data.'
          a.privacy = 'public'
        end

        agreement.agreement_terms.find_or_create_by!(identifier: 'privacy_policy_summary') do |term|
          term.protected = true
          term.position = 1
          term.content = 'We respect your privacy and protect your personal information.'
        end

        # If a Page exists for the privacy policy, link it so the page content
        # is shown to users instead of the agreement terms.
        page = BetterTogether::Page.find_by(identifier: 'privacy_policy') ||
               BetterTogether::Page.find_by(slug: 'privacy-policy')
        agreement.update!(page: page) if page.present?
      end

      def build_terms_of_service # rubocop:todo Metrics/MethodLength
        agreement = BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') do |a|
          a.protected = true
          a.title = 'Terms of Service'
          a.description = 'Rules you agree to when using the platform.'
          a.privacy = 'public'
        end

        agreement.agreement_terms.find_or_create_by!(identifier: 'terms_of_service_summary') do |term|
          term.protected = true
          term.position = 1
          term.content = 'Use the platform responsibly and respectfully.'
        end

        # Link a Terms of Service Page if one exists
        page = BetterTogether::Page.find_by(identifier: 'terms_of_service') ||
               BetterTogether::Page.find_by(slug: 'terms-of-service')
        agreement.update!(page: page) if page.present?
      end
    end
  end
end
