# frozen_string_literal: true

module TrixHelpers
  # Fill a Trix editor by setting the associated hidden input field.
  # locator: CSS locator for the <trix-editor> element
  def fill_in_trix_editor(locator = 'trix-editor', with:)
    editor = find(locator)
    editor.click
    input_id = editor[:input]
    raise 'Trix editor missing input attribute' if input_id.blank?

    # Set value via JS to avoid Selenium restrictions on hidden inputs
    script = <<~JS
      (function(){
        var el = document.getElementById('#{input_id}');
        if(!el) return;
        el.value = #{with.to_json};
        var event = new Event('input', { bubbles: true });
        el.dispatchEvent(event);
      })();
    JS
    page.execute_script(script)
  end
end

RSpec.configure do |config|
  config.include TrixHelpers, type: :feature
end
