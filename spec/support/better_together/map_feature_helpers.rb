# frozen_string_literal: true

require 'timeout'

module BetterTogether
  module MapFeatureHelpers
    MAP_CONTROLLER_IDENTIFIER = 'better_together--map'

    def wait_for_leaflet_map(selector = '.map', timeout: Capybara.default_max_wait_time)
      expect(page).to have_css("#{selector}.leaflet-container", wait: timeout)

      Timeout.timeout(timeout) do
        loop do
          ready = page.evaluate_script(map_controller_script(<<~JS), selector)
            return Boolean(context && controller && controller.map)
          JS
          return if ready

          sleep 0.05
        end
      end
    end

    def leaflet_map_state(selector = '.map')
      page.evaluate_script(map_controller_script(<<~JS), selector)
        if (!context || !controller || !controller.map) {
          return null
        }

        const markerLayers = []
        controller.map.eachLayer((layer) => {
          if (layer instanceof globalThis.L.Marker) {
            markerLayers.push(layer)
          }
        })

        return {
          center: controller.map.getCenter(),
          hasOsmLayer: controller.map.hasLayer(controller.osmLayer),
          hasSatelliteLayer: controller.map.hasLayer(controller.satelliteLayer),
          markerCount: markerLayers.length,
          popupHtml: markerLayers[0] && markerLayers[0].getPopup() ? markerLayers[0].getPopup().getContent() : null
        }
      JS
    end

    def stub_browser_geolocation(latitude:, longitude:, accuracy: 5)
      page.execute_script(<<~JS, latitude, longitude, accuracy)
        const latitude = arguments[0]
        const longitude = arguments[1]
        const accuracy = arguments[2]

        Object.defineProperty(window.navigator, 'geolocation', {
          configurable: true,
          value: {
            getCurrentPosition(success) {
              success({
                coords: { latitude, longitude, accuracy },
                timestamp: Date.now()
              })
            }
          }
        })
      JS
    end

    private

    def map_controller_script(expression)
      <<~JS
        (() => {
          const selector = arguments[0]
          const element = document.querySelector(selector)
          const application = window.Stimulus
          if (!element || !application) {
            return null
          }

          const module = application.router.modulesByIdentifier.get("#{MAP_CONTROLLER_IDENTIFIER}")
          if (!module) {
            return null
          }

          const context = Array.from(module.contexts).find((entry) => entry.element === element)
          const controller = context && context.controller

          #{expression}
        })()
      JS
    end
  end
end
