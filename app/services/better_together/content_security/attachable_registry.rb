# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Block classes a host app (or an engine) allows inside rich text next to uploaded files. Rich text rejects every
    # attachment that is not an ActiveStorage blob; a registered class (it must include ActionText::Attachable and
    # provide its own attachment partial) is accepted, and rendered only while it is public and visible, so a signed
    # id copied from a restricted block cannot expose it through another record's body.
    #
    #   BetterTogether::ContentSecurity::AttachableRegistry.register('BetterTogether::Content::Image')
    module AttachableRegistry
      @class_names = Concurrent::Array.new

      class << self
        def register(*class_names)
          class_names.flatten.map(&:to_s).each { |name| @class_names << name unless @class_names.include?(name) }
        end

        def class_names
          @class_names.to_a
        end

        def allowed?(attachable)
          @class_names.include?(attachable.class.name)
        end

        def renderable?(attachable)
          allowed?(attachable) && attachable.privacy_public? && attachable.visible?
        end

        def reset!
          @class_names.clear
        end
      end
    end
  end
end
