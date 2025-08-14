# frozen_string_literal: true

# Helper for rendering form fields with consistent error handling and
# Bootstrap invalid-feedback blocks.
module FormFieldHelper
  # Renders a form field wrapped with label and error markup.
  #
  # @param form [ActionView::Helpers::FormBuilder]
  # @param attribute [Symbol] model attribute name
  # @param method [Symbol] form builder method (:text_field, :select, ...)
  # @param label [Boolean,String] true for default label, false to omit or a
  #   custom label string
  # @param wrapper_class [String,nil] CSS classes for the wrapper div. Pass nil
  #   to skip the wrapper.
  # @param input_class [String] base CSS classes for the input element
  # @param help_text [String,nil] optional help text displayed under the field
  # @param options [Hash] additional options passed to the form builder method
  # @yield [input_class] yields the computed input class when a block is given.
  # @return [String] HTML safe string for the field
  def form_field(form, attribute, method: nil, label: true, wrapper_class: 'mb-3', input_class: nil, help_text: nil, **options, &block)
    errors = form.object.errors[attribute]
    final_input_class = [input_class, (errors.any? ? 'is-invalid' : nil)].compact.join(' ')

    field_html = if block_given?
                   capture(final_input_class, &block)
                 else
                   options[:class] = final_input_class
                   form.public_send(method || :text_field, attribute, **options)
                 end

    content = ActiveSupport::SafeBuffer.new
    label_text = label.is_a?(String) ? label : nil
    content << form.label(attribute, label_text) if label
    content << field_html
    content << content_tag(:div, errors.join(', '), class: 'invalid-feedback') if errors.any?
    content << content_tag(:small, help_text, class: 'form-text text-muted mt-2') if help_text

    wrapper_class ? content_tag(:div, content, class: wrapper_class) : content
  end
end
