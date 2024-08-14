# frozen_string_literal: true

# config/initializers/action_text.rb
Rails.application.config.after_initialize do
  default_allowed_attributes =
    Rails::HTML5::Sanitizer.safe_list_sanitizer.allowed_attributes.to_set +
    ActionText::Attachment::ATTRIBUTES.to_set
  custom_allowed_attributes = Set.new(%w[style href])
  ActionText::ContentHelper.allowed_attributes =
    (default_allowed_attributes + custom_allowed_attributes).freeze

  # default_allowed_tags = Rails::HTML5::Sanitizer.safe_list_sanitizer.allowed_tags.to_set +
  # Set.new([ActionText::Attachment.tag_name, "figure", "figcaption"])
  # custom_allowed_tags = Set.new(%w[audio video source])
  # ActionText::ContentHelper.allowed_tags = (default_allowed_tags + custom_allowed_tags).freeze
end
