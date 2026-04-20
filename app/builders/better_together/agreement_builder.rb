# frozen_string_literal: true

# app/builders/better_together/agreement_builder.rb

module BetterTogether
  # Builder to seed initial agreements
  class AgreementBuilder < Builder # rubocop:disable Metrics/ClassLength
    class << self
      def seed_data
        build_privacy_policy
        build_terms_of_service
        build_code_of_conduct
        build_content_publishing_agreement
      end

      def clear_existing
        BetterTogether::AgreementParticipant.delete_all
        BetterTogether::AgreementTerm.delete_all
        BetterTogether::Agreement.delete_all
      end

      # rubocop:todo Metrics/AbcSize
      def build_privacy_policy # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
        agreement = BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') do |a|
          a.protected = true
          a.title = 'Privacy Policy'
          a.description = 'Summary of how we handle your data.'
          a.privacy = 'public'
          a.agreement_kind = 'policy_consent'
          a.required_for = 'registration'
          a.active_for_consent = true
        end

        agreement.update!(
          protected: true,
          title: 'Privacy Policy',
          description: 'Summary of how we handle your data.',
          privacy: 'public',
          agreement_kind: 'policy_consent',
          required_for: 'registration',
          active_for_consent: true
        )

        agreement.agreement_terms.find_or_create_by!(identifier: 'privacy_policy_summary') do |term|
          term.protected = true
          term.position = 1
          term.content = 'We respect your privacy and protect your personal information.'
        end

        ensure_agreement_page_link!(
          agreement:,
          page_identifier: 'privacy_policy',
          page_title: 'Privacy Policy',
          page_slug: 'privacy-policy',
          template_path: 'better_together/static_pages/privacy'
        )
      end
      # rubocop:enable Metrics/AbcSize

      # rubocop:todo Metrics/AbcSize
      def build_terms_of_service # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
        agreement = BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') do |a|
          a.protected = true
          a.title = 'Terms of Service'
          a.description = 'Rules you agree to when using the platform.'
          a.privacy = 'public'
          a.agreement_kind = 'policy_consent'
          a.required_for = 'registration'
          a.active_for_consent = true
        end

        agreement.update!(
          protected: true,
          title: 'Terms of Service',
          description: 'Rules you agree to when using the platform.',
          privacy: 'public',
          agreement_kind: 'policy_consent',
          required_for: 'registration',
          active_for_consent: true
        )

        agreement.agreement_terms.find_or_create_by!(identifier: 'terms_of_service_summary') do |term|
          term.protected = true
          term.position = 1
          term.content = 'Use the platform responsibly and respectfully.'
        end

        ensure_agreement_page_link!(
          agreement:,
          page_identifier: 'terms_of_service',
          page_title: 'Terms of Service',
          page_slug: 'terms-of-service',
          template_path: 'better_together/static_pages/terms_of_service'
        )
      end
      # rubocop:enable Metrics/AbcSize

      # rubocop:todo Metrics/MethodLength
      def build_code_of_conduct # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        agreement = BetterTogether::Agreement.find_or_create_by!(identifier: 'code_of_conduct') do |a|
          a.protected = true
          a.title = 'Code of Conduct'
          a.description = 'Community code of conduct and expectations.'
          a.privacy = 'public'
          a.agreement_kind = 'policy_consent'
          a.required_for = 'registration'
          a.active_for_consent = true
        end

        agreement.update!(
          protected: true,
          title: 'Code of Conduct',
          description: 'Community code of conduct and expectations.',
          privacy: 'public',
          agreement_kind: 'policy_consent',
          required_for: 'registration',
          active_for_consent: true
        )

        agreement.agreement_terms.find_or_create_by!(identifier: 'code_of_conduct_summary') do |term|
          term.protected = true
          term.position = 1
          term.content = 'Be respectful, inclusive, and considerate to other community members.'
        end

        ensure_agreement_page_link!(
          agreement:,
          page_identifier: 'code_of_conduct',
          page_title: 'Code of Conduct',
          page_slug: 'code-of-conduct',
          template_path: 'better_together/static_pages/code_of_conduct'
        )
      end
      # rubocop:enable Metrics/MethodLength

      def build_content_publishing_agreement # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        agreement = BetterTogether::Agreement.find_or_create_by!(identifier: 'content_publishing_agreement') do |a|
          a.protected = true
          a.title = 'Content Publishing Agreement'
          a.description = 'Consent requirement for making content or identity information publicly visible.'
          a.privacy = 'public'
          a.agreement_kind = 'publishing_consent'
          a.required_for = 'first_publish'
          a.active_for_consent = true
        end

        agreement.update!(
          protected: true,
          title: 'Content Publishing Agreement',
          description: 'Consent requirement for making content or identity information publicly visible.',
          privacy: 'public',
          agreement_kind: 'publishing_consent',
          required_for: 'first_publish',
          active_for_consent: true
        )

        agreement.agreement_terms.find_or_create_by!(identifier: 'content_publishing_agreement_summary') do |term|
          term.protected = true
          term.position = 1
          term.content = <<~CONTENT
            Public publishing can expose content and identity information to the wider community and public internet.
            Publishing agents must respect consent, privacy, attribution, safety, and truthful representation,
            and must not expose other people or communities without authorization.
          CONTENT
        end

        ensure_agreement_page_link!(
          agreement:,
          page_identifier: 'content_contributor_agreement',
          page_title: 'Content Contributor Agreement',
          page_slug: 'content-contributor-agreement',
          template_path: 'better_together/static_pages/content_contributor_agreement'
        )
      end

      private

      def ensure_agreement_page_link!(agreement:, page_identifier:, page_title:, page_slug:, template_path:)
        page = find_or_build_agreement_page(
          identifier: page_identifier,
          title: page_title,
          slug: page_slug,
          template_path:
        )

        agreement.update!(page:) if agreement.page != page
      end

      def find_or_build_agreement_page(identifier:, title:, slug:, template_path:) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        page = BetterTogether::Page.find_by(identifier:) ||
               BetterTogether::Page.i18n.find_by(slug:) ||
               BetterTogether::Page.i18n.find_by(title:)

        page ||= BetterTogether::Page.new(identifier:)

        page.assign_attributes(
          platform: Current.platform || BetterTogether::Platform.find_by(host: true) || BetterTogether::Platform.first,
          title:,
          slug:,
          published_at: Time.zone.now,
          privacy: 'public',
          protected: true,
          show_title: false
        )
        page.save! if page.new_record? || page.changed?

        ensure_template_block!(page:, template_path:)
        page
      end

      def ensure_template_block!(page:, template_path:)
        template_block = page.template_blocks.detect { |block| block.template_path == template_path }
        return if template_block.present?

        page.page_blocks.create!(
          block: BetterTogether::Content::Template.create!(
            template_path:,
            css_settings: { container_class: '', css_classes: 'my-4' }
          )
        )
      end
    end
  end
end
