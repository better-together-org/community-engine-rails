# frozen_string_literal: true

module BetterTogether
  module Billing
    # The host's agreements with the platforms it hosts, seeded on the HOST platform as drafts with placeholder text:
    #
    #   hosted_platform_billing_agreement  any billing at all on a hosted platform
    #   hosted_local_billing_agreement     cash, cheque and e-transfer on a hosted platform (the host holds no liability for them)
    #   merchant_onboarding_agreement      the host collecting as merchant of record (the mode itself is built later)
    #
    # Nothing is unlocked until the host reviews and activates an agreement and the hosted platform accepts it (see HostedBilling).
    # Seeding again never touches an agreement a steward edited or activated.
    class HostedAgreementSeeds
      IDENTIFIERS = %w[hosted_platform_billing_agreement hosted_local_billing_agreement merchant_onboarding_agreement].freeze

      # rubocop:disable Layout/LineLength
      TITLES = {
        'hosted_platform_billing_agreement' => { en: 'Hosted Platform Billing Agreement', es: 'Acuerdo de facturación de plataforma alojada',
                                                 fr: 'Accord de facturation de plateforme hébergée', uk: 'Угода про білінг розміщеної платформи' },
        'hosted_local_billing_agreement' => { en: 'Hosted Local Billing Agreement', es: 'Acuerdo de facturación local de plataforma alojada',
                                              fr: 'Accord de facturation locale de plateforme hébergée',
                                              uk: 'Угода про локальний білінг розміщеної платформи' },
        'merchant_onboarding_agreement' => { en: 'Merchant Onboarding Agreement', es: 'Acuerdo de incorporación como comerciante',
                                             fr: 'Accord d\'intégration comme commerçant', uk: 'Угода про підключення як продавця' }
      }.freeze

      DESCRIPTIONS = {
        'hosted_platform_billing_agreement' => { en: 'Terms for selling anything through the host: what the platform is responsible for, and what the host is not.',
                                                 es: 'Términos para vender a través del anfitrión: de qué es responsable la plataforma y de qué no lo es el anfitrión.',
                                                 fr: 'Conditions pour vendre par l\'hôte : ce dont la plateforme est responsable et ce dont l\'hôte ne l\'est pas.',
                                                 uk: 'Умови продажу через хост: за що відповідає платформа і за що не відповідає хост.' },
        'hosted_local_billing_agreement' => { en: 'Terms for taking cash, cheque and e-transfer payments: the host does not track, guarantee or hold liability for them.',
                                              es: 'Términos para cobrar en efectivo, cheque y transferencia: el anfitrión no los rastrea, garantiza ni asume responsabilidad.',
                                              fr: 'Conditions pour les paiements en espèces, chèque et virement : l\'hôte ne les suit pas, ne les garantit pas et n\'en est pas responsable.',
                                              uk: 'Умови прийому готівки, чеків та переказів: хост не відстежує, не гарантує і не відповідає за них.' },
        'merchant_onboarding_agreement' => { en: 'Terms for the host collecting payments for the platform as merchant of record, and paying out.',
                                             es: 'Términos para que el anfitrión cobre por la plataforma como comerciante registrado y le pague.',
                                             fr: 'Conditions pour que l\'hôte encaisse pour la plateforme comme commerçant de référence et lui reverse les fonds.',
                                             uk: 'Умови, за яких хост приймає платежі для платформи як торговий агент і виплачує кошти.' }
      }.freeze

      # rubocop:enable Layout/LineLength

      def self.call(host) = new(host).call

      def initialize(host)
        @host = host
      end

      # { identifier => Agreement } on the host.
      def call
        IDENTIFIERS.to_h { |identifier| [identifier, agreement(identifier)] }
      end

      private

      attr_reader :host

      def agreement(identifier)
        record = Agreement.find_or_create_by!(identifier:, platform: host) do |new_agreement|
          new_agreement.assign_attributes(localized(title: TITLES.fetch(identifier), description: DESCRIPTIONS.fetch(identifier))
            .merge(PurchaseAgreementSeeds::DRAFT_ATTRIBUTES, change_summary: PurchaseAgreementSeeds.placeholder.fetch(:en)))
        end
        plant_summary_term(record)
        record
      end

      def plant_summary_term(record)
        record.agreement_terms.find_or_create_by!(identifier: "#{record.identifier}_summary_#{host.id.delete('-').first(12)}") do |term|
          term.assign_attributes(localized(content: PurchaseAgreementSeeds.placeholder).merge(protected: true, position: 1))
        end
      end

      def localized(attributes)
        attributes.each_with_object({}) do |(attribute, values), flat|
          values.each { |locale, value| flat[:"#{attribute}_#{locale}"] = value }
        end
      end
    end
  end
end
