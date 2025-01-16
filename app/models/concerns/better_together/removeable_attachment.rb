# frozen_string_literal: true

module BetterTogether
  module RemoveableAttachment # rubocop:todo Style/Documentation
    extend ::ActiveSupport::Concern
    included do
      # rubocop:todo Lint/ConstantDefinitionInBlock
      ATTACHMENT_ATTRIBUTES = [] # rubocop:todo Style/MutableConstant, Lint/ConstantDefinitionInBlock
      # rubocop:enable Lint/ConstantDefinitionInBlock

      # define accessors, before_save callback, and purge method for all declared has_one attachments
      reflect_on_all_attachments
        .filter { |association| association.instance_of? ActiveStorage::Reflection::HasOneAttachedReflection }
        .map(&:name).each do |attachment|
        # Virtual attributes to track removal

        remove_attachment_attr = :"remove_#{attachment}"
        attr_accessor :"remove_#{attachment}"

        ATTACHMENT_ATTRIBUTES.push(attachment, remove_attachment_attr)

        # Callbacks to remove images if necessary
        before_save :"purge_#{attachment}", if: -> { public_send(remove_attachment_attr) == '1' }

        define_method "purge_#{attachment}" do
          public_send(attachment).purge_later
        end
      end
    end

    class_methods do
      def extra_permitted_attributes
        super + ATTACHMENT_ATTRIBUTES.flatten.compact
      end
    end
  end
end
