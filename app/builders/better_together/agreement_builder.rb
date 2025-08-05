# frozen_string_literal: true

module BetterTogether
  # Seeds default agreements like terms of service and privacy policy
  class AgreementBuilder < Builder
    class << self
      def seed_data
        ::BetterTogether::Agreement.create!(agreement_attrs)
      end

      def clear_existing
        ::BetterTogether::AgreementParticipant.delete_all
        ::BetterTogether::AgreementTerm.delete_all
        ::BetterTogether::Agreement.delete_all
      end

      private

      # rubocop:disable Metrics/MethodLength
      def agreement_attrs
        [
          {
            identifier: 'privacy_policy',
            protected: true,
            title: 'Privacy Policy',
            agreement_terms_attributes: [
              {
                identifier: 'privacy_policy_overview',
                summary: 'We respect your privacy and only collect necessary data.',
                position: 1,
                content: 'Full privacy policy content.'
              }
            ]
          },
          {
            identifier: 'terms_of_service',
            protected: true,
            title: 'Terms of Service',
            agreement_terms_attributes: [
              {
                identifier: 'tos_overview',
                summary: 'Use the platform responsibly and be kind to others.',
                position: 1,
                content: 'Full terms of service content.'
              }
            ]
          }
        ]
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
