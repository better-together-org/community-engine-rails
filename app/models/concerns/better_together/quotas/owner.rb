# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Concern for models that can hold a BetterTogether::Quota (Person, Community,
    # Platform today). Dynamic extension point, same pattern as Commentable: a model
    # becomes a valid quota owner purely by including this concern, not via a
    # gem-owned hardcoded allow-list. See
    # docs/developers/architecture/polymorphic_allowlist_extension_audit.md
    module Owner
      extend ActiveSupport::Concern

      included do
        # No `dependent:` here: Quota restricts deleting its append-only usages, so a
        # plain :destroy would raise DeleteRestrictionError for any owner with usage
        # and block person/community/platform deletion. erase_quota_ledger below
        # removes the owner's whole ledger instead, and is prepended so it runs ahead
        # of any other dependent callbacks.
        has_many :quotas, as: :owner, class_name: 'BetterTogether::Quota'

        before_destroy :erase_quota_ledger, prepend: true
      end

      def self.included_in_models
        included_module = self
        Rails.application.eager_load! unless Rails.env.production?
        ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
      end

      private

      # Deleting the owner deletes its ledger: usage history for an owner that no
      # longer exists has nothing left to be counted against. delete_all bypasses
      # QuotaUsage's readonly/before_destroy guards, which exist to stop ad-hoc edits,
      # not owner erasure. Rows where this record was only the *actor* on someone
      # else's quota keep the usage but drop the reference to it, since owner/actor
      # are polymorphic (no FK) and so are invisible to PersonAssociationAudit.
      # rubocop:todo Metrics/AbcSize
      def erase_quota_ledger
        quota_ids = BetterTogether::Quota.where(owner: self).select(:id)

        BetterTogether::QuotaUsage.where(quota_id: quota_ids).delete_all
        BetterTogether::QuotaReservation.where(quota_id: quota_ids).delete_all
        BetterTogether::QuotaBalance.where(quota_id: quota_ids).delete_all
        BetterTogether::Quota.where(owner: self).delete_all
        # QuotaGrant is keyed by owner+quota_type directly, not quota_id, so it is not
        # reachable via quota_ids above and needs its own cleanup here.
        BetterTogether::QuotaGrant.where(owner: self).delete_all

        BetterTogether::QuotaUsage.where(actor: self).update_all(actor_type: nil, actor_id: nil)
        BetterTogether::QuotaReservation.where(actor: self).update_all(actor_type: nil, actor_id: nil)
        BetterTogether::QuotaGrant.where(granted_by: self).update_all(granted_by_type: nil, granted_by_id: nil)
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
