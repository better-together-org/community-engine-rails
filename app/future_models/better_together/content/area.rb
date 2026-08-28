module BetterTogether
  module Content
    class Area < ApplicationRecord
      include BetterTogether::Creatable
      include BetterTogether::Positioned
      include BetterTogether::Privacy
      include BetterTogether::Visible

      belongs_to :parent, polymorphic: true, touch: true

      belongs_to :block, polymorphic: true, autosave: true

      accepts_nested_attributes_for :block, allow_destroy: true

      validate :no_self_reference

      # Ensure block_type is set to the specific STI subclass
      # def block_attributes=(attributes)
      #   block_class = attributes[:type].constantize
      #   area_block = nil
      #   if attributes[:id].present?
      #     area_block = block_class.find(attributes[:id])
      #   else
      #     area_block = block_class.new(attributes.except(:type, :id))
      #   end
      #   area_block.save!

      #   self.block = area_block

      #   self.block_id = area_block.id # Explicitly set the block_type
      #   self.block_type = area_block.class.name # Explicitly set the block_type

      #   raise self
      # end

      # def build_block(attrs={})
      # raise self
      #   block_class = attrs[:type].constantize
      #   self.block_type = block_class
      #   # block = super attrs
      #   self.block = super attrs
      #   raise attributes
      # end

      def no_self_reference
        raise self
        errors.add :block, 'no self-reference in content areas' if contentable_id == block_id
      end

    end
  end
end
