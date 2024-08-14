# frozen_string_literal: true

Rails.application.config.after_initialize do
  # Example of safe array modification
  if ActionText::ContentHelper.allowed_attributes.frozen?
    ActionText::ContentHelper.allowed_attributes = ActionText::ContentHelper.allowed_attributes.to_a + %w[style href]
  else
    ActionText::ContentHelper.allowed_attributes << 'style'
    ActionText::ContentHelper.allowed_attributes << 'href'
  end
end
