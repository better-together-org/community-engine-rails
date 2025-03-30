# frozen_string_literal: true

module BetterTogether
  module PrimaryFlag # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      class_attribute :primary_flag_scope_key, default: nil
      class_attribute :allow_blank_scoped_id, default: false

      validates :primary_flag, inclusion: { in: [true, false] }
      validate :only_one_primary_flag

      after_initialize :set_default_primary_flag, if: :new_record?
    end

    class_methods do
      def extra_permitted_attributes
        super + [:primary_flag]
      end

      def has_primary_for(parent_id) # rubocop:todo Naming/PredicateName
        return false unless parent_id && primary_flag_scope_key

        where(primary_flag: true, primary_flag_scope_key => parent_id).exists?
      end

      def primary_record(parent_id = nil) # rubocop:todo Naming/PredicateName
        return find_by(primary_flag: true) unless parent_id && primary_flag_scope_key

        find_by(primary_flag: true, primary_flag_scope_key => parent_id)
      end

      def primary_flag_scope(parent_key = nil, allow_blank: false)
        self.primary_flag_scope_key = parent_key
        self.allow_blank_scoped_id = allow_blank
      end
    end

    private

    def only_one_primary_flag # rubocop:todo Metrics/AbcSize
      return unless primary_flag

      query = self.class.where(primary_flag: true).where.not(id:)

      if primary_flag_scope_key
        parent_id = send(primary_flag_scope_key)
        return if parent_id.nil? && self.class.allow_blank_scoped_id

        values = [parent_id]
        query = query.where(primary_flag_scope_key => values)
      end

      return unless query.exists?

      scope_message = primary_flag_scope_key ? " per #{primary_flag_scope_key.to_s.humanize}" : ''
      errors.add(:primary_flag, :only_one_primary,
                 message: I18n.t('better_together.errors.only_one_primary', scope: scope_message))
    end

    def set_default_primary_flag
      return unless primary_flag_scope_key

      parent_id = send(primary_flag_scope_key)
      return unless parent_id

      if self.class.has_primary_for(parent_id)
        self.primary_flag ||= false
      else
        self.primary_flag = true
      end
    end
  end
end
