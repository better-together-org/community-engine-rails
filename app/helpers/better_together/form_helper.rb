
module BetterTogether
  # Facilitates building forms by pulling out reusable components and logic
  module FormHelper
    def privacy_field(form:, klass:)
      form.select :privacy, klass.privacies.keys.map { |privacy| [privacy.humanize, privacy] }, {}, { class: 'form-select', required: true }
    end

    def required_label(form_or_object, field, options = {})
      # Determine if it's a form object or just an object
      if form_or_object.respond_to?(:object)
        object = form_or_object.object
        label_text = object.class.human_attribute_name(field)
        is_required = object.class.validators_on(field).any? { |v| v.kind == :presence }
      else
        object = form_or_object
        label_text = object.class.human_attribute_name(field)
        is_required = object.class.validators_on(field).any? { |v| v.kind == :presence }
      end

      # Append asterisk for required fields
      label_text += " <span class='required-indicator'>*</span>" if is_required

      if form_or_object.respond_to?(:label)
        form_or_object.label(field, label_text.html_safe, options)
      else
        label_tag(field, label_text.html_safe, options)
      end
    end
  end
end