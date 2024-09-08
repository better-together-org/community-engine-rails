module BetterTogether
  module Content
    class RichText < Block
      include Translatable

      translates :content, backend: :action_text
    end
  end
end
