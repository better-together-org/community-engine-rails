
module BetterTogether
  # Facilitates building forms by pulling out reusable components and logic
  module FormHelper
    def privacy_field(form:, klass:)
      form.select :privacy, klass.privacies.keys.map { |privacy| [privacy.humanize, privacy] }, {}, { class: 'form-select', required: true }
    end
  end
end