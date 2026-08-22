// Test file for better_together/location_selector_controller.js
// This tests the mixed-search event-location-picker's post-selection behavior: splitting
// a composite "ClassName:id" value from the picker select back into the plain
// location_id/location_type hidden fields, falling back to the simple `name` field for
// unmatched free text, and the inline "+New" block open/close/disable flow.
//
// Note: this repo has no JS test runner configured at all (no package.json, no jest
// config, node present but no npm/npx) — verified via careful manual review against the
// source and a Node syntax check, not by executing the suite (same caveat as the prior
// version of this file — see 9c0709dcd).

import { Application } from "@hotwired/stimulus"
import LocationSelectorController from "../../../app/javascript/controllers/better_together/location_selector_controller"

const LOCATION_TYPE_MAP = {
  address: "BetterTogether::Address",
  building: "BetterTogether::Infrastructure::Building",
  settlement: "BetterTogether::Geography::Settlement"
}

// Mirrors the real DOM structure rendered by
// app/views/better_together/events/_form.html.erb — one mixed-search picker select
// (deliberately NOT the real location_id field — see that view's own comment on why),
// three hidden fields the controller writes to, and one newRecordButton/newRecordBlock
// pair per inline-creatable type (address/building only — settlement is lookup-only, no
// "+New" pair).
const mockDOM = `
  <form data-controller="better_together--location-selector"
        data-better_together--location-selector-location-type-map-value='${JSON.stringify(LOCATION_TYPE_MAP)}'>
    <select id="event_location_picker" data-better_together--location-selector-target="locationSelect"
            data-action="change->better_together--location-selector#applyLocationSelection">
      <option value=""></option>
    </select>

    <input type="hidden" name="event[location_attributes][location_id]"
           data-better_together--location-selector-target="locationIdField">
    <input type="hidden" name="event[location_attributes][location_type]"
           data-better_together--location-selector-target="locationTypeField">
    <input type="hidden" name="event[location_attributes][name]"
           data-better_together--location-selector-target="simpleNameField">

    <a href="#" data-location-type="address"
       data-action="click->better_together--location-selector#showNewRecord"
       data-better_together--location-selector-target="newRecordButton">New</a>
    <a href="#" data-location-type="building"
       data-action="click->better_together--location-selector#showNewRecord"
       data-better_together--location-selector-target="newRecordButton">New</a>

    <div data-location-type="address" data-better_together--location-selector-target="newRecordBlock"
         style="display: none;">
      <input type="text" name="event[location_attributes][location_attributes][line1]">
    </div>
    <div data-location-type="building" data-better_together--location-selector-target="newRecordBlock"
         style="display: none;">
      <input type="text" name="event[location_attributes][location_attributes][name]">
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

    it("starts every newRecordBlock's fields disabled, even though the blocks were already display:none in markup", () => {
      controller.newRecordBlockTargets.forEach((block) => {
        block.querySelectorAll("input, select, textarea").forEach((field) => {
          expect(field.disabled).toBe(true)
        })
      })
    })
  })

  describe("matchLocationType", () => {
    it("matches a composite value's class-name prefix against locationTypeMapValue", () => {
      expect(controller.matchLocationType("BetterTogether::Address:abc-123")).toBe("BetterTogether::Address")
    })

    it("returns null for a value that doesn't start with any known class name", () => {
      expect(controller.matchLocationType("Cottage on the hill")).toBeNull()
    })

    it("returns null for a value containing a colon that isn't a known class-name prefix", () => {
      expect(controller.matchLocationType("Room: 204")).toBeNull()
    })
  })

  describe("applyLocationSelection — structured pick", () => {
    it("splits a composite value into location_id/location_type and clears the simple name field", () => {
      controller.simpleNameFieldTarget.value = "stale simple name"
      controller.locationSelectTarget.innerHTML =
        '<option value="BetterTogether::Address:abc-123" selected>123 Main St (Address)</option>'

      controller.applyLocationSelection()

      expect(controller.locationIdFieldTarget.value).toBe("abc-123")
      expect(controller.locationTypeFieldTarget.value).toBe("BetterTogether::Address")
      expect(controller.simpleNameFieldTarget.value).toBe("")
    })

    it("closes and disables every open newRecordBlock when an existing location is picked", () => {
      const [addressButton] = controller.newRecordButtonTargets
      controller.showNewRecord({ preventDefault: () => {}, currentTarget: addressButton })
      const [addressBlock] = controller.newRecordBlockTargets
      expect(addressBlock.style.display).toBe("block")

      controller.locationSelectTarget.innerHTML =
        '<option value="BetterTogether::Address:abc-123" selected>123 Main St (Address)</option>'
      controller.applyLocationSelection()

      expect(addressBlock.style.display).toBe("none")
      addressBlock.querySelectorAll("input, select, textarea").forEach((field) => {
        expect(field.disabled).toBe(true)
      })
    })
  })

  describe("applyLocationSelection — free-text (addable) fallback", () => {
    it("writes unmatched typed text into the simple name field and clears the structured fields", () => {
      controller.locationIdFieldTarget.value = "stale-id"
      controller.locationTypeFieldTarget.value = "BetterTogether::Address"
      controller.locationSelectTarget.innerHTML =
        '<option value="A Custom Venue Name" selected>A Custom Venue Name</option>'

      controller.applyLocationSelection()

      expect(controller.simpleNameFieldTarget.value).toBe("A Custom Venue Name")
      expect(controller.locationIdFieldTarget.value).toBe("")
      expect(controller.locationTypeFieldTarget.value).toBe("")
    })
  })

  describe("applyLocationSelection — cleared selection", () => {
    it("clears both structured and simple fields when the picker value is blank", () => {
      controller.locationIdFieldTarget.value = "abc-123"
      controller.locationTypeFieldTarget.value = "BetterTogether::Address"
      controller.simpleNameFieldTarget.value = "A Custom Venue Name"
      controller.locationSelectTarget.value = ""

      controller.applyLocationSelection()

      expect(controller.locationIdFieldTarget.value).toBe("")
      expect(controller.locationTypeFieldTarget.value).toBe("")
      expect(controller.simpleNameFieldTarget.value).toBe("")
    })
  })

  describe("showNewRecord", () => {
    it("opens the matching newRecordBlock and enables its fields", () => {
      const [addressButton] = controller.newRecordButtonTargets
      const [addressBlock] = controller.newRecordBlockTargets

      controller.showNewRecord({ preventDefault: () => {}, currentTarget: addressButton })

      expect(addressBlock.style.display).toBe("block")
      addressBlock.querySelectorAll("input, select, textarea").forEach((field) => {
        expect(field.disabled).toBe(false)
      })
    })

    it("closes an already-open block and disables its fields when clicked again", () => {
      const [addressButton] = controller.newRecordButtonTargets
      const [addressBlock] = controller.newRecordBlockTargets

      controller.showNewRecord({ preventDefault: () => {}, currentTarget: addressButton })
      controller.showNewRecord({ preventDefault: () => {}, currentTarget: addressButton })

      expect(addressBlock.style.display).toBe("none")
      addressBlock.querySelectorAll("input, select, textarea").forEach((field) => {
        expect(field.disabled).toBe(true)
      })
    })

    it("is independent per type — opening address doesn't touch building's block", () => {
      const [addressButton] = controller.newRecordButtonTargets
      const [addressBlock, buildingBlock] = controller.newRecordBlockTargets

      controller.showNewRecord({ preventDefault: () => {}, currentTarget: addressButton })

      expect(addressBlock.style.display).toBe("block")
      expect(buildingBlock.style.display).toBe("none")
    })
  })
})
