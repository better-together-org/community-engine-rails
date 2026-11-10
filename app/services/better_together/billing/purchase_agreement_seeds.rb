# frozen_string_literal: true

module BetterTogether
  module Billing
    # Seeds a platform's purchase agreements and ties them to the purchases they cover:
    #
    #   subscription_agreement         subscriptions and memberships
    #   one_time_purchase_agreement    one-time purchases, event tickets and exchanges
    #   offline_payment_terms          added when a buyer pays by cash, cheque or e-transfer
    #
    # They are seeded as DRAFTS with placeholder text, and until a steward reviews and activates
    # them nothing can be sold (see Checkout::AgreementGate), so placeholder legal text never goes
    # live by accident. Seeding again never touches an agreement a steward has edited or
    # activated: it only creates what is missing.
    class PurchaseAgreementSeeds
      PLACEHOLDER = {
        en: 'This is placeholder text. Replace it with your own terms, then set the agreement to active.',
        es: 'Este es un texto provisional. Sustitúyalo por sus propios términos y luego active el acuerdo.',
        fr: 'Ceci est un texte provisoire. Remplacez-le par vos propres conditions, puis activez l\'accord.',
        uk: 'Це тимчасовий текст. Замініть його власними умовами, а потім активуйте угоду.'
      }.freeze

      # Wording per locale. The es, fr and uk text wants a translator's review before it is activated.
      AGREEMENTS = {
        'subscription_agreement' => {
          title: { en: 'Subscription Agreement', es: 'Acuerdo de suscripción', fr: "Accord d'abonnement", uk: 'Угода про підписку' },
          description: {
            en: 'Terms for subscriptions and memberships: what you receive, how renewal works, and how to cancel.',
            es: 'Términos de las suscripciones y membresías: qué recibe, cómo funciona la renovación y cómo cancelar.',
            fr: "Conditions des abonnements et adhésions : ce que vous recevez, le fonctionnement du renouvellement et l'annulation.",
            uk: 'Умови підписок і членства: що ви отримуєте, як працює поновлення та як скасувати.'
          }
        },
        'one_time_purchase_agreement' => {
          title: { en: 'One-Time Purchase Agreement', es: 'Acuerdo de compra única', fr: "Accord d'achat unique",
                   uk: 'Угода про разову покупку' },
          description: {
            en: 'Terms for one-time purchases, event tickets and exchanges: what you receive and how refunds work.',
            es: 'Términos de las compras únicas, entradas a eventos e intercambios: qué recibe y cómo funcionan los reembolsos.',
            fr: 'Conditions des achats uniques, billets et échanges : ce que vous recevez et le fonctionnement des remboursements.',
            uk: 'Умови разових покупок, квитків на події та обмінів: що ви отримуєте і як працюють повернення коштів.'
          }
        },
        'offline_payment_terms' => {
          title: { en: 'Payment Outside the Platform', es: 'Pago fuera de la plataforma', fr: 'Paiement hors de la plateforme',
                   uk: 'Оплата поза платформою' },
          description: {
            en: 'Terms for paying by cash, cheque or e-transfer: the payment goes straight to the seller, ' \
                'and the platform cannot track or protect it.',
            es: 'Términos para pagar en efectivo, con cheque o por transferencia electrónica: el pago va directamente al vendedor ' \
                'y la plataforma no puede rastrearlo ni protegerlo.',
            fr: 'Conditions du paiement comptant, par chèque ou par virement : le paiement va directement au vendeur ' \
                'et la plateforme ne peut ni le suivre ni le protéger.',
            uk: 'Умови оплати готівкою, чеком або електронним переказом: платіж іде безпосередньо продавцю, ' \
                'а платформа не може його відстежити чи захистити.'
          }
        }
      }.freeze

      REQUIREMENTS = [
        ['subscription_agreement', 'subscription', nil],
        ['one_time_purchase_agreement', 'one_time', nil],
        ['one_time_purchase_agreement', 'ticket', nil],
        ['one_time_purchase_agreement', 'exchange', nil],
        ['offline_payment_terms', nil, 'cash'],
        ['offline_payment_terms', nil, 'cheque'],
        ['offline_payment_terms', nil, 'etransfer']
      ].freeze

      def self.call(platform) = new(platform).call

      def initialize(platform)
        @platform = platform
      end

      def call
        # The method terms below name the built-in methods, so they must be installed.
        Billing.ensure_builtin_processors!
        agreements = AGREEMENTS.to_h { |identifier, attributes| [identifier, agreement(identifier, attributes)] }
        REQUIREMENTS.each { |identifier, purpose, method| requirement(agreements.fetch(identifier), purpose, method) }
        agreements
      end

      private

      attr_reader :platform

      def agreement(identifier, attributes)
        record = Agreement.find_or_create_by!(identifier:, platform:) do |new_agreement|
          new_agreement.assign_attributes(localized(attributes).merge(protected: true, privacy: 'public',
                                                                      agreement_kind: 'transactional_agreement', required_for: 'none',
                                                                      active_for_consent: true, lifecycle_state: 'draft',
                                                                      requires_reacceptance: true, change_summary: PLACEHOLDER[:en]))
        end
        # A term's identifier is unique across platforms (its table indexes it alone), so it carries the platform.
        record.agreement_terms.find_or_create_by!(identifier: "#{identifier}_summary_#{platform.id.delete('-').first(12)}") do |term|
          term.assign_attributes(localized(content: PLACEHOLDER).merge(protected: true, position: 1))
        end
        record
      end

      # { title: { en:, fr: } } becomes { title_en:, title_fr: }, the writers Mobility gives each locale.
      def localized(attributes)
        attributes.each_with_object({}) do |(attribute, values), flat|
          values.each { |locale, value| flat[:"#{attribute}_#{locale}"] = value }
        end
      end

      def requirement(agreement, purpose, payment_method)
        platform.billing_agreement_requirements.find_or_create_by!(agreement:, purpose:, payment_method:, target_type: nil, target_id: nil)
      end
    end
  end
end
