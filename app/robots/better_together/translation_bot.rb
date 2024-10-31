module BetterTogether
  class TranslationBot < ApplicationBot
    def translate(content, target_locale:, attribute_name: nil, model_name: nil)
      # Step 1: Replace Trix attachments with placeholders
      attachments = {}
      processed_content = content.gsub(/<figure[^>]+data-trix-attachment="([^"]+)"[^>]*>.*?<\/figure>/) do |match|
        placeholder = "TRIX_ATTACHMENT_PLACEHOLDER_#{attachments.size}"
        attachments[placeholder] = match
        placeholder
      end

      # Step 2: Translate the content without attachments
      response = client.chat(
        parameters: {
          model: 'gpt-4o-mini-2024-07-18',
          messages: [
            { role: 'system', content: "You are a translation assistant for CMS content. Translate text accurately for each type of content provided. Only return the translated text without any added explanation or commentary." },
            { role: 'user', content: "Translate the following text to #{target_locale}: #{processed_content}" }
          ],
          temperature: 0.1,
          max_tokens: 1000
        }
      )

      translated_content = response.dig('choices', 0, 'message', 'content') || "Translation unavailable"

      # Step 3: Replace placeholders with original attachments
      attachments.each do |placeholder, original_attachment|
        translated_content.gsub!(placeholder, original_attachment)
      end

      translated_content
    end
  end
end
