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
      page.evaluate_script(map_controller_script(leaflet_state_js), selector)
    end

    # A public community whose building is geocoded, so the communities index renders a map with one pin.
    def create_mapped_community(creator:, name: 'Mapped Community', latitude: 48.9517, longitude: -57.9474)
      community = create(:better_together_community, :open_access, creator:, name:, privacy: 'public')
      address = build(:better_together_address, line1: '62 Broadway', city_name: 'Corner Brook',
                                                state_province_name: 'Newfoundland and Labrador', postal_code: 'A2H 4C2',
                                                country_name: 'Canada', privacy: 'public', primary_flag: true)
      building = create(:better_together_infrastructure_building, creator:, name: "#{name} Hall", privacy: 'public',
                                                                  address:)
      BetterTogether::Infrastructure::BuildingConnection.create!(building:, connection: community, position: 1,
                                                                 primary_flag: true)
      building.geospatial_space.space.assign_attributes(latitude:, longitude:)
      building.geospatial_space.save!
      community.reload
    end

    # Real browser behaviour through the Chrome DevTools Protocol: the page is granted location permission and the
    # browser reports this position, so the actual getCurrentPosition path runs (no JavaScript stub).
    def grant_browser_geolocation(latitude:, longitude:, accuracy: 20)
      cdp('Browser.grantPermissions', permissions: ['geolocation'], origin: page_origin)
      cdp('Emulation.setGeolocationOverride', latitude:, longitude:, accuracy:)
    end

    # The browser refuses location for this page, as when the user blocks it in the permission prompt or settings.
    def deny_browser_geolocation
      cdp('Browser.setPermission', permission: { name: 'geolocation' }, setting: 'denied', origin: page_origin)
    end

    # Replaces navigator.geolocation.getCurrentPosition with a scripted sequence, one entry per call:
    # { position: { latitude:, longitude:, accuracy: } }, { error: 1 | 2 | 3 } (PERMISSION_DENIED, POSITION_UNAVAILABLE,
    # TIMEOUT) or { pending: true } (never answers). Every call's options are recorded in window.__geolocationCalls.
    def script_browser_geolocation(*steps)
      page.execute_script(scripted_geolocation_js, steps)
    end

    def geolocation_calls
      page.evaluate_script('window.__geolocationCalls')
    end

    # The browser has no Geolocation API at all.
    def remove_browser_geolocation
      page.execute_script("Object.defineProperty(window.navigator, 'geolocation', { configurable: true, value: undefined })")
    end

    # Records alert() calls instead of blocking on them, so a spec can assert that none were shown.
    def record_browser_alerts
      page.execute_script('window.__alerts = []; window.alert = (message) => window.__alerts.push(message)')
    end

    def browser_alerts
      page.evaluate_script('window.__alerts')
    end

    def stub_browser_geolocation(latitude:, longitude:, accuracy: 5)
      page.execute_script(geolocation_stub_js, latitude, longitude, accuracy)
    end

    # Runs JavaScript with the map element's Stimulus controller in scope as `controller`; the selector is
    # arguments[0] and any further arguments follow.
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

    private

    def cdp(command, **params)
      page.driver.browser.execute_cdp(command, **params)
    end

    def page_origin
      page.evaluate_script('window.location.origin')
    end

    def scripted_geolocation_js
      <<~JS
        const steps = arguments[0]
        window.__geolocationCalls = []
        Object.defineProperty(window.navigator, 'geolocation', {
          configurable: true,
          value: {
            getCurrentPosition(success, error, options) {
              const step = steps[window.__geolocationCalls.length] || steps[steps.length - 1]
              window.__geolocationCalls.push(options)
              if (step.pending) { return }
              if (step.error) { error({ code: step.error, message: 'scripted error ' + step.error }); return }
              success({ coords: step.position, timestamp: Date.now() })
            }
          }
        })
      JS
    end

    def leaflet_state_js
      <<~JS
        if (!context || !controller || !controller.map) { return null }
        const markerLayers = []
        controller.map.eachLayer((layer) => {
          if (layer instanceof globalThis.L.Marker) { markerLayers.push(layer) }
        })
        return {
          center: controller.map.getCenter(),
          hasOsmLayer: controller.map.hasLayer(controller.osmLayer),
          hasSatelliteLayer: controller.map.hasLayer(controller.satelliteLayer),
          zoom: controller.map.getZoom(),
          geolocationState: controller.geolocationState,
          positionShown: Boolean(controller.positionLayer && controller.map.hasLayer(controller.positionLayer)),
          markerCount: markerLayers.length,
          popupHtml: markerLayers[0]?.getPopup()?.getContent() || null
        }
      JS
    end

    def geolocation_stub_js
      <<~JS
        const stubbedLatitude = arguments[0]
        const stubbedLongitude = arguments[1]
        const stubbedAccuracy = arguments[2]
        Object.defineProperty(window.navigator, 'geolocation', {
          configurable: true,
          value: {
            getCurrentPosition(success) {
              success({
                coords: { latitude: stubbedLatitude, longitude: stubbedLongitude, accuracy: stubbedAccuracy },
                timestamp: Date.now()
              })
            }
          }
        })
      JS
    end
  end
end
