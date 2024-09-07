module BetterTogether
  module Content
    class RichText < Block
      translates :content, backend: :action_text
    end
  end
end
