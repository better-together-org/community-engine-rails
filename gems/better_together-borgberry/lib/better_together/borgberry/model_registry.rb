# frozen_string_literal: true

module BetterTogether
  module Borgberry
    # Tracks host-model decorations owned by the Borgberry extension, applied via
    # Engine#config.to_prepare. Mirrors the pattern used by the (now externally
    # hosted) better_together-elasticsearch extension's ModelRegistry: core CE
    # models carry no direct knowledge of C3/Fleet — the extension reaches in
    # from the outside once it's bundled.
    module ModelRegistry
      DEFAULT_MODEL_DECORATIONS = {
        'BetterTogether::Person' => 'BetterTogether::Borgberry::Decorations::Person',
        'BetterTogether::Community' => 'BetterTogether::Borgberry::Decorations::Community',
        'BetterTogether::PlatformConnection' => 'BetterTogether::Borgberry::Decorations::PlatformConnection',
        'BetterTogether::Joatu::Agreement' => 'BetterTogether::Borgberry::Decorations::JoatuAgreement'
      }.freeze

      mattr_accessor :model_decorations, default: {}

      module_function

      def register_default_decorations!
        DEFAULT_MODEL_DECORATIONS.each do |model_name, concern_name|
          register_model_decoration(model_name:, concern_name:)
        end
      end

      def register_model_decoration(model_name:, concern_name:)
        self.model_decorations = model_decorations.merge(model_name => concern_name)
      end

      def apply_model_decorations!
        model_decorations.each do |model_name, concern_name|
          model = model_name.constantize
          concern = concern_name.constantize
          # prepend (not include): JoatuAgreement's hook overrides rely on `super`
          # reaching the core class's no-op method definitions, which only works
          # if the decoration sits ahead of the class itself in the ancestor chain.
          model.prepend(concern) unless model < concern
        end
      end
    end
  end
end
