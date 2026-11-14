# frozen_string_literal: true

# axe samples colours at call time, so a Bootstrap fade or modal transition that is still
# running yields blended foreground/background values and intermittent color-contrast
# failures. Disable motion and wait for running animations to finish before every audit.
module AxeMotionSettle
  DISABLE_MOTION_JS = <<~JS
    if (!document.getElementById('axe-no-motion')) {
      var style = document.createElement('style');
      style.id = 'axe-no-motion';
      style.textContent = '*, *::before, *::after { transition: none !important; animation: none !important; }';
      document.head.appendChild(style);
    }
  JS
  PENDING_ANIMATIONS_JS = 'document.getAnimations().length'

  def audit(page)
    AxeMotionSettle.settle(page) unless @audit
    super
  end

  def self.settle(page)
    page.execute_script(DISABLE_MOTION_JS)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    while page.evaluate_script(PENDING_ANIMATIONS_JS).to_i.positive?
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  rescue Capybara::NotSupportedByDriverError
    nil
  end
end

Axe::Matchers::BeAxeClean.prepend(AxeMotionSettle)
