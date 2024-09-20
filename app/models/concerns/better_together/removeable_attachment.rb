
module BetterTogether
  module RemoveableAttachment
    extend ::ActiveSupport::Concern
    included do
      ATTACHMENT_ATTRIBUTES = []

      # define accessors, before_save callback, and purge method for all declared has_one attachments
      self.reflect_on_all_attachments
        .filter { |association| association.instance_of? ActiveStorage::Reflection::HasOneAttachedReflection }
        .map(&:name).each do |attachment|
        # Virtual attributes to track removal

        remove_attachment_attr = "remove_#{attachment}".to_sym
        attr_accessor "remove_#{attachment}".to_sym

        ATTACHMENT_ATTRIBUTES.concat([attachment, remove_attachment_attr])

        # Callbacks to remove images if necessary
        before_save "purge_#{attachment}".to_sym, if: -> { public_send(remove_attachment_attr) == '1' }

        define_method "purge_#{attachment}" do
          public_send(attachment).purge_later
        end
      end

      def self.extra_permitted_attributes
        [*ATTACHMENT_ATTRIBUTES.flatten.compact, *super]
      end
    end
  end
end