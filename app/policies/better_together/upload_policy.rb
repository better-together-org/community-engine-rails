# frozen_string_literal: true

module BetterTogether
  # Access control for files
  class UploadPolicy < PlatformRecordPolicy
    def index?
      user.present?
    end

    def show?
      user.present? && record.creator == agent
    end

    # An invoice or receipt is the platform's record of a sale: the buyer who is its creator may read it, not rewrite it.
    def update?
      user.present? && record.creator == agent && !order_document?
    end

    def create?
      user.present?
    end

    def download?
      (record.privacy_public? || record.creator == agent || stewards_order_document?) &&
        record.attached?
    end

    def order_document?
      BetterTogether::Billing::OrderDocument.exists?(upload_id: record.id)
    end

    # The invoice or receipt of a sale the platform's stewards manage can be downloaded by them too.
    def stewards_order_document?
      return false unless user.present?

      order = BetterTogether::Billing::OrderDocument.find_by(upload_id: record.id)&.order
      order.present? && BetterTogether::Billing::OrderPolicy.new(user, order).sale?
    end

    # Filtering and sorting for files according to permissions and context
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        platform_scoped.with_creator(agent).order(created_at: :desc)
      end
    end
  end
end
