// Test file for better_together/location_selector_controller.js
// This tests the dynamic event-location-picker form behavior: switching between
// simple/structured location types, and showing/hiding inline "+New" record blocks
// for whichever Placeable types are inline-creatable (Address/Building).

import { Application } from "@hotwired/stimulus"
import LocationSelectorController from "../../../app/javascript/controllers/better_together/location_selector_controller"

const LOCATION_TYPE_MAP = {
  address: "BetterTogether::Address",
  building: "BetterTogether::Infrastructure::Building",
  settlement: "BetterTogether::Geography::Settlement"
}

// Mirrors the real DOM structure rendered by
// app/views/better_together/events/_form.html.erb — one radio per
// location_type_map key plus "simple", a unified structured-location select,
// and one newRecordButton/newRecordBlock pair per inline-creatable type
// (address/building only — settlement is lookup-only, no "+New" pair).
const mockDOM = `
  <form data-controller="better_together--location-selector"
        data-better_together--location-selector-location-type-map-value='${JSON.stringify(LOCATION_TYPE_MAP)}'
        data-better_together--location-selector-available-locations-url-value="/events/available_locations">
    <div data-better_together--location-selector-target="typeSelector">
      <input type="radio" name="location_type_selector" id="simple_location" value="simple">
      <input type="radio" name="location_type_selector" id="address_location" value="address">
      <input type="radio" name="location_type_selector" id="building_location" value="building">
      <input type="radio" name="location_type_selector" id="settlement_location" value="settlement">
    </div>

    <div data-better_together--location-selector-target="simpleLocation" style="display: none;">
      <input type="text" name="event[location_attributes][name]">
    </div>

    <div data-better_together--location-selector-target="structuredLocation" style="display: none;">
      <select name="event[location_attributes][location_id]"
              data-better_together--location-selector-target="locationIdSelect"></select>
      <input type="hidden" name="event[location_attributes][location_type]"
             data-better_together--location-selector-target="locationTypeField">

      <a href="#" data-location-type="address"
         data-action="click->better_together--location-selector#showNewRecord"
         data-better_together--location-selector-target="newRecordButton" style="display: none;">New</a>
      <a href="#" data-location-type="building"
         data-action="click->better_together--location-selector#showNewRecord"
         data-better_together--location-selector-target="newRecordButton" style="display: none;">New</a>

      <div data-location-type="address" data-better_together--location-selector-target="newRecordBlock"
           style="display: none;">
        <input type="text" name="event[location_attributes][location_attributes][line1]">
      </div>
      <div data-location-type="building" data-better_together--location-selector-target="newRecordBlock"
           style="display: none;">
        <input type="text" name="event[location_attributes][location_attributes][name]">
      </div>
    </div>
  </form>
`

describe("LocationSelectorController", () => {
  let application
  let controller
  let element

  beforeEach(() => {
    document.body.innerHTML = mockDOM

    application = Application.start()
    application.register("better_together--location-selector", LocationSelectorController)

    element = document.querySelector('[data-controller="better_together--location-selector"]')
    controller = application.getControllerForElementAndIdentifier(
      element,
      "better_together--location-selector"
    )
  })

  afterEach(() => {
    document.body.innerHTML = ""
    if (application) {
      application.stop()
    }
  })

  describe("connect", () => {
    it("connects successfully", () => {
      expect(controller).toBeDefined()
    })

    it("defaults to simple location and checks the simple radio when nothing is checked", () => {
      expect(controller.simpleLocationTarget.style.display).toBe("block")
      expect(controller.structuredLocationTarget.style.display).toBe("none")
      expect(element.querySelector("#simple_location").checked).toBe(true)
    })
  })

  describe("toggleLocationType", () => {
    it("shows the structured section and hides the simple section for a non-simple type", () => {
      controller.toggleLocationType({ target: { value: "address" } })

      expect(controller.structuredLocationTarget.style.display).toBe("block")
      expect(controller.simpleLocationTarget.style.display).toBe("none")
    })

    it("shows the simple section and hides the structured section for 'simple'", () => {
      controller.toggleLocationType({ target: { value: "address" } })
      controller.toggleLocationType({ target: { value: "simple" } })

      expect(controller.simpleLocationTarget.style.display).toBe("block")
      expect(controller.structuredLocationTarget.style.display).toBe("none")
    })

    it("writes the mapped class name into the hidden location_type field", () => {
      controller.toggleLocationType({ target: { value: "building" } })

      expect(controller.locationTypeFieldTarget.value).toBe("BetterTogether::Infrastructure::Building")
    })

    it("points the location_id select's SlimSelect ajax source at the selected type", () => {
      controller.toggleLocationType({ target: { value: "address" } })

      const optionsValue = controller.locationIdSelectTarget.getAttribute(
        "data-better_together--slim-select-options-value"
      )
      const parsed = JSON.parse(optionsValue)

      expect(parsed.ajax.url).toContain("location_type=BetterTogether%3A%3AAddress")
    })
  })

  describe("showStructuredLocation — inline '+New' button visibility", () => {
    it("shows only the matching type's newRecordButton", () => {
      controller.toggleLocationType({ target: { value: "address" } })

      const [addressButton, buildingButton] = controller.newRecordButtonTargets
      expect(addressButton.style.display).toBe("inline-block")
      expect(buildingButton.style.display).toBe("none")
    })

    it("shows no newRecordButton for a lookup-only type like settlement", () => {
      controller.toggleLocationType({ target: { value: "settlement" } })

      controller.newRecordButtonTargets.forEach((button) => {
        expect(button.style.display).toBe("none")
      })
    })
  })

  describe("showNewRecord", () => {
    it("opens the matching newRecordBlock and enables its fields", () => {
      controller.toggleLocationType({ target: { value: "address" } })
      const [addressButton] = controller.newRecordButtonTargets
      const [addressBlock] = controller.newRecordBlockTargets

      controller.showNewRecord({ preventDefault: () => {}, currentTarget: addressButton })

      expect(addressBlock.style.display).toBe("block")
      addressBlock.querySelectorAll("input, select, textarea").forEach((field) => {
        expect(field.disabled).toBe(false)
      })
    })

    it("closes an already-open block and disables its fields when clicked again", () => {
      controller.toggleLocationType({ target: { value: "address" } })
      const [addressButton] = controller.newRecordButtonTargets
      const [addressBlock] = controller.newRecordBlockTargets

      controller.showNewRecord({ preventDefault: () => {}, currentTarget: addressButton })
      controller.showNewRecord({ preventDefault: () => {}, currentTarget: addressButton })

      expect(addressBlock.style.display).toBe("none")
      addressBlock.querySelectorAll("input, select, textarea").forEach((field) => {
        expect(field.disabled).toBe(true)
      })
    })
  })

  describe("hideAllLocationTypes", () => {
    it("hides and disables every newRecordBlock so hidden fields never POST", () => {
      controller.toggleLocationType({ target: { value: "address" } })
      const [addressButton] = controller.newRecordButtonTargets
      controller.showNewRecord({ preventDefault: () => {}, currentTarget: addressButton })

      controller.hideAllLocationTypes()

      controller.newRecordBlockTargets.forEach((block) => {
        expect(block.style.display).toBe("none")
        block.querySelectorAll("input, select, textarea").forEach((field) => {
          expect(field.disabled).toBe(true)
        })
      })
    })
  })

  describe("clearStructuredLocationFields", () => {
    it("resets the location_id select and location_type field", () => {
      controller.toggleLocationType({ target: { value: "address" } })
      controller.locationIdSelectTarget.innerHTML = '<option value="">Select…</option><option value="1">Existing</option>'
      controller.locationIdSelectTarget.selectedIndex = 1

      controller.clearStructuredLocationFields()

      expect(controller.locationIdSelectTarget.selectedIndex).toBe(0)
      expect(controller.locationTypeFieldTarget.value).toBe("")
    })
  })
})
