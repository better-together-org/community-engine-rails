// Test file for better_together/location_selector_controller.js
// Covers the mixed-search event-location picker: splitting a composite
// "ClassName:id" value from the picker select back into the plain
// location_id/location_type hidden fields, the free-text fallback to the simple
// `name` field, and the inline "create a new address" fieldset reveal/cancel flow
// driven by the better_together--slim-select:create custom event.
//
// Note: this repo has no JS test runner configured (no package.json, no jest
// config, node present but no npm/npx) — verified via manual review against the
// source and a Node syntax check, not by executing the suite (same caveat as the
// prior version of this file — see 9c0709dcd).

import { Application } from "@hotwired/stimulus"
import LocationSelectorController from "../../../app/javascript/controllers/better_together/location_selector_controller"

const LOCATION_TYPE_MAP = {
  address: "BetterTogether::Address",
  building: "BetterTogether::Infrastructure::Building",
  settlement: "BetterTogether::Geography::Settlement"
}

// Mirrors app/views/better_together/events/_form.html.erb: one mixed-search picker
// select, three hidden fields the controller writes to, a visually-hidden live
// region, and the single inline address <fieldset> (hidden + a legend caption
// span). No "+New" anchors and no Building block — inline Building creation was
// removed; Building stays selectable from the search only.
const mockDOM = `
  <div data-controller="better_together--location-selector"
       data-better_together--location-selector-location-type-map-value='${JSON.stringify(LOCATION_TYPE_MAP)}'
       data-better_together--location-selector-new-record-opened-announcement-value="Creating a new address."
       data-better_together--location-selector-new-record-cancelled-announcement-value="New address cancelled.">
    <div class="ss-main" tabindex="0"></div>
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

    <div class="visually-hidden" role="status"
         data-better_together--location-selector-target="announcement"></div>

    <fieldset id="event_location_new_address" data-location-type="address"
              data-better_together--location-selector-target="newRecordBlock" hidden>
      <legend>New address
        <span data-better_together--location-selector-target="newRecordQuery"></span>
      </legend>
      <input type="text" name="event[location_attributes][location_attributes][line1]">
      <button type="button" data-better_together--location-selector-target="cancelNewRecordButton"
              data-action="click->better_together--location-selector#cancelNewRecord">Cancel</button>
    </fieldset>
  </div>
`

const createEvent = (type, query) => new CustomEvent("better_together--slim-select:create", {
  bubbles: true,
  detail: { type, query }
})

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
    if (application) application.stop()
  })

  describe("connect", () => {
    it("connects successfully", () => {
      expect(controller).toBeDefined()
    })

    it("starts the hidden newRecordBlock's fields disabled", () => {
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
  })

  describe("applyLocationSelection — free-text fallback", () => {
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
      controller.simpleNameFieldTarget.value = "A Custom Venue Name"
      controller.locationSelectTarget.value = ""

      controller.applyLocationSelection()

      expect(controller.locationIdFieldTarget.value).toBe("")
      expect(controller.locationTypeFieldTarget.value).toBe("")
      expect(controller.simpleNameFieldTarget.value).toBe("")
    })
  })

  describe("revealNewRecord — address", () => {
    it("shows the fieldset, enables its fields, prefills line1, sets the caption and location_type", () => {
      element.dispatchEvent(createEvent("address", "42 Elm St"))

      const block = controller.newRecordBlockTargets[0]
      expect(block.hidden).toBe(false)
      expect(block.querySelector('input[name*="[line1]"]').disabled).toBe(false)
      expect(block.querySelector('input[name*="[line1]"]').value).toBe("42 Elm St")
      expect(controller.newRecordQueryTarget.textContent).toBe('"42 Elm St"')
      expect(controller.locationTypeFieldTarget.value).toBe("BetterTogether::Address")
    })

    it("ignores a create event for a type with no matching block (e.g. simple)", () => {
      element.dispatchEvent(createEvent("simple", "My Backyard"))

      expect(controller.newRecordBlockTargets[0].hidden).toBe(true)
    })
  })

  describe("cancelNewRecord", () => {
    it("hides and disables the fieldset, clears every hidden field, and refocuses the combobox", () => {
      element.dispatchEvent(createEvent("address", "9 Cancel Rd"))
      const block = controller.newRecordBlockTargets[0]
      expect(block.hidden).toBe(false)

      controller.cancelNewRecord(new Event("click"))

      expect(block.hidden).toBe(true)
      expect(block.querySelector('input[name*="[line1]"]').disabled).toBe(true)
      expect(controller.locationIdFieldTarget.value).toBe("")
      expect(controller.locationTypeFieldTarget.value).toBe("")
      expect(controller.simpleNameFieldTarget.value).toBe("")
    })
  })

  describe("mutual exclusion", () => {
    it("closes an open address fieldset when an existing location is then picked", () => {
      element.dispatchEvent(createEvent("address", "Draft address"))
      const block = controller.newRecordBlockTargets[0]
      expect(block.hidden).toBe(false)

      controller.locationSelectTarget.innerHTML =
        '<option value="BetterTogether::Geography::Settlement:s-1" selected>Corner Brook (Settlement)</option>'
      controller.applyLocationSelection()

      expect(block.hidden).toBe(true)
      expect(controller.locationTypeFieldTarget.value).toBe("BetterTogether::Geography::Settlement")
    })
  })
})
