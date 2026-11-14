# frozen_string_literal: true

module BetterTogether
  module Billing
    # Seeds a platform's purchase agreements and ties them to the purchases they cover:
    #
    #   subscription_agreement         subscriptions and memberships
    #   one_time_purchase_agreement    one-time purchases, event tickets and exchanges
    #   offline_payment_terms          added when a buyer pays by cash, cheque or e-transfer
    #
    # The wording and the ties live in the packet
    # config/seeds/better_together/billing_agreements/billing_purchase_agreements.yml, which is also what the seed catalog
    # plants. They are seeded as DRAFTS with placeholder text, and until a steward reviews and activates them nothing can
    # be sold (see Checkout::AgreementGate), so placeholder legal text never goes live by accident. Seeding again never
    # touches an agreement a steward has edited or activated: it only creates what is missing.
    class PurchaseAgreementSeeds
      PACKET_PATH = BetterTogether::Engine.root.join('config/seeds/better_together/billing_agreements/billing_purchase_agreements.yml')

      # The packet, read once: { placeholder:, agreements: [...], requirements: [...] } with symbol keys. The wording is data
      # in the packet (a Seed envelope, like the tax packets), not code.
      DRAFT_ATTRIBUTES = { protected: true, privacy: 'public', agreement_kind: 'transactional_agreement', required_for: 'none',
                           active_for_consent: true, lifecycle_state: 'draft', requires_reacceptance: true }.freeze

      def self.packet = @packet ||= Seed.safe_load_yaml_file(PACKET_PATH.to_s)

      def self.data = @data ||= packet.fetch(Seed::DEFAULT_ROOT_KEY).deep_symbolize_keys.fetch(:purchase_agreements)

      def self.placeholder = data.fetch(:placeholder)

      # True when the platform has every agreement and every purchase tie the packet names.
      def self.planted?(platform)
        identifiers = data.fetch(:agreements).pluck(:identifier)
        Agreement.where(platform:, identifier: identifiers).count == identifiers.size &&
          data.fetch(:requirements).all? { |entry| requirement_planted?(platform, entry) }
      end

      def self.requirement_planted?(platform, entry)
        agreement = Agreement.find_by(platform:, identifier: entry.fetch(:agreement))
        agreement && platform.billing_agreement_requirements.exists?(requirement_attributes(agreement, entry))
      end

      def self.requirement_attributes(agreement, entry)
        { agreement:, purpose: entry[:purpose], payment_method: entry[:payment_method], target_type: nil, target_id: nil }
      end
      private_class_method :requirement_planted?, :requirement_attributes

      def self.call(platform) = new(platform).call

      def initialize(platform)
        @platform = platform
      end

      def call
        # The method terms below name the built-in methods, so they must be installed.
        Billing.ensure_builtin_processors!
        ::ActiveRecord::Base.transaction do
          Seed.import_or_update!(self.class.packet)
          agreements = self.class.data.fetch(:agreements).to_h { |entry| [entry.fetch(:identifier), agreement(entry)] }
          plant_requirements(agreements)
          agreements
        end
      end

      private

      attr_reader :platform

      def plant_requirements(agreements)
        self.class.data.fetch(:requirements).each do |entry|
          requirement(agreements.fetch(entry.fetch(:agreement)), entry[:purpose], entry[:payment_method])
        end
      end

      def agreement(entry)
        record = Agreement.find_or_create_by!(identifier: entry.fetch(:identifier), platform:) do |new_agreement|
          new_agreement.assign_attributes(localized(entry.slice(:title, :description)).merge(DRAFT_ATTRIBUTES,
                                                                                             change_summary: self.class.placeholder.fetch(:en)))
        end
        plant_summary_term(record)
        record
      end

      # A term's identifier is unique across platforms (its table indexes it alone), so it carries the platform.
      def plant_summary_term(record)
        record.agreement_terms.find_or_create_by!(identifier: "#{record.identifier}_summary_#{platform.id.delete('-').first(12)}") do |term|
          term.assign_attributes(localized(content: self.class.placeholder).merge(protected: true, position: 1))
        end
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
