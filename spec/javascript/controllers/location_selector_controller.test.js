// Test file for location_selector_controller.js
// This tests the dynamic form behavior for location selection

import { Application } from "@hotwired/stimulus"
import LocationSelectorController from "../../../app/javascript/controllers/location_selector_controller"

// Mock DOM elements
const mockDOM = `
  <form data-controller="location-selector">
    <fieldset data-location-selector-target="simpleLocationFields">
      <label for="location_name">Location Name</label>
      <input type="text" id="location_name" name="event[location_attributes][name]">
    </fieldset>
    
    <fieldset data-location-selector-target="structuredLocationFields" style="display: none;">
      <label for="location_type">Location Type</label>
      <select id="location_type" name="event[location_attributes][location_type]" 
              data-location-selector-target="locationTypeSelect"
              data-action="change->location-selector#onLocationTypeChange">
        <option value="">Select location type...</option>
        <option value="BetterTogether::Geography::Address">Address</option>
        <option value="BetterTogether::Geography::Building">Building</option>
      </select>
      
      <div data-location-selector-target="locationOptions" style="display: none;">
        <select name="event[location_attributes][location_id]" 
                data-location-selector-target="locationSelect">
          <option value="">Select location...</option>
        </select>
      </div>
    </fieldset>
    
    <div class="form-switch">
      <label>
        <input type="checkbox" 
               data-location-selector-target="locationModeToggle"
               data-action="change->location-selector#toggleLocationMode">
        Use structured location
      </label>
    </div>
  </form>
`

describe("LocationSelectorController", () => {
  let application
  let controller

  beforeEach(() => {
    // Setup DOM
    document.body.innerHTML = mockDOM
    
    // Setup Stimulus application
    application = Application.start()
    application.register("location-selector", LocationSelectorController)
    
    // Get controller instance
    const element = document.querySelector('[data-controller="location-selector"]')
    controller = application.getControllerForElementAndIdentifier(element, "location-selector")
  })

  afterEach(() => {
    document.body.innerHTML = ""
    if (application) {
      application.stop()
    }
  })

  describe("initialization", () => {
    it("connects successfully", () => {
      expect(controller).toBeDefined()
    })

    it("has all required targets", () => {
      expect(controller.simpleLocationFieldsTarget).toBeTruthy()
      expect(controller.structuredLocationFieldsTarget).toBeTruthy()
      expect(controller.locationModeToggleTarget).toBeTruthy()
      expect(controller.locationTypeSelectTarget).toBeTruthy()
      expect(controller.locationOptionsTarget).toBeTruthy()
      expect(controller.locationSelectTarget).toBeTruthy()
    })

    it("starts in simple location mode", () => {
      expect(controller.simpleLocationFieldsTarget.style.display).toBe("")
      expect(controller.structuredLocationFieldsTarget.style.display).toBe("none")
      expect(controller.locationModeToggleTarget.checked).toBeFalsy()
    })
  })

  describe("toggleLocationMode", () => {
    it("switches to structured mode when toggle is checked", () => {
      controller.locationModeToggleTarget.checked = true
      controller.toggleLocationMode()

      expect(controller.simpleLocationFieldsTarget.style.display).toBe("none")
      expect(controller.structuredLocationFieldsTarget.style.display).toBe("")
    })

    it("switches back to simple mode when toggle is unchecked", () => {
      // First switch to structured mode
      controller.locationModeToggleTarget.checked = true
      controller.toggleLocationMode()
      
      // Then switch back
      controller.locationModeToggleTarget.checked = false
      controller.toggleLocationMode()

      expect(controller.simpleLocationFieldsTarget.style.display).toBe("")
      expect(controller.structuredLocationFieldsTarget.style.display).toBe("none")
    })

    it("clears simple location name when switching to structured", () => {
      const nameInput = document.getElementById("location_name")
      nameInput.value = "Test Location"
      
      controller.locationModeToggleTarget.checked = true
      controller.toggleLocationMode()

      expect(nameInput.value).toBe("")
    })

    it("clears structured location selections when switching to simple", () => {
      // Set up structured location
      controller.locationTypeSelectTarget.value = "BetterTogether::Geography::Address"
      controller.locationSelectTarget.value = "123"
      
      // Switch to simple mode
      controller.locationModeToggleTarget.checked = false
      controller.toggleLocationMode()

      expect(controller.locationTypeSelectTarget.value).toBe("")
      expect(controller.locationSelectTarget.value).toBe("")
    })
  })

  describe("onLocationTypeChange", () => {
    beforeEach(() => {
      // Switch to structured mode first
      controller.locationModeToggleTarget.checked = true
      controller.toggleLocationMode()
    })

    it("shows location options when type is selected", () => {
      controller.locationTypeSelectTarget.value = "BetterTogether::Geography::Address"
      controller.onLocationTypeChange()

      expect(controller.locationOptionsTarget.style.display).toBe("")
    })

    it("hides location options when no type is selected", () => {
      controller.locationTypeSelectTarget.value = ""
      controller.onLocationTypeChange()

      expect(controller.locationOptionsTarget.style.display).toBe("none")
    })

    it("makes API request to fetch location options", async () => {
      // Mock fetch
      global.fetch = jest.fn(() =>
        Promise.resolve({
          ok: true,
          json: () => Promise.resolve([
            { id: 1, display_name: "123 Main St" },
            { id: 2, display_name: "456 Oak Ave" }
          ])
        })
      )

      controller.locationTypeSelectTarget.value = "BetterTogether::Geography::Address"
      await controller.onLocationTypeChange()

      expect(fetch).toHaveBeenCalledWith(
        "/better_together/geography/locations/options?type=BetterTogether::Geography::Address",
        expect.objectContaining({
          headers: expect.objectContaining({
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          })
        })
      )
    })

    it("populates location select with fetched options", async () => {
      const mockLocations = [
        { id: 1, display_name: "123 Main St" },
        { id: 2, display_name: "456 Oak Ave" }
      ]

      global.fetch = jest.fn(() =>
        Promise.resolve({
          ok: true,
          json: () => Promise.resolve(mockLocations)
        })
      )

      controller.locationTypeSelectTarget.value = "BetterTogether::Geography::Address"
      await controller.onLocationTypeChange()

      const options = controller.locationSelectTarget.options
      expect(options.length).toBe(3) // Default option + 2 locations
      expect(options[1].value).toBe("1")
      expect(options[1].text).toBe("123 Main St")
      expect(options[2].value).toBe("2")
      expect(options[2].text).toBe("456 Oak Ave")
    })

    it("handles API errors gracefully", async () => {
      global.fetch = jest.fn(() =>
        Promise.resolve({
          ok: false,
          status: 500
        })
      )

      console.error = jest.fn()

      controller.locationTypeSelectTarget.value = "BetterTogether::Geography::Address"
      await controller.onLocationTypeChange()

      expect(console.error).toHaveBeenCalledWith(
        "Failed to fetch location options:", 
        expect.any(Error)
      )
    })

    it("clears location select when type changes", async () => {
      // Set initial options
      controller.locationSelectTarget.innerHTML = `
        <option value="">Select location...</option>
        <option value="1">Old Location</option>
      `

      global.fetch = jest.fn(() =>
        Promise.resolve({
          ok: true,
          json: () => Promise.resolve([])
        })
      )

      controller.locationTypeSelectTarget.value = "BetterTogether::Geography::Building"
      await controller.onLocationTypeChange()

      const options = controller.locationSelectTarget.options
      expect(options.length).toBe(1)
      expect(options[0].value).toBe("")
    })
  })

  describe("form validation", () => {
    it("validates simple location has name", () => {
      const nameInput = document.getElementById("location_name")
      nameInput.value = ""
      
      const isValid = controller.validateForm()
      expect(isValid).toBeFalsy()
    })

    it("validates structured location has both type and selection", () => {
      controller.locationModeToggleTarget.checked = true
      controller.toggleLocationMode()
      
      controller.locationTypeSelectTarget.value = "BetterTogether::Geography::Address"
      controller.locationSelectTarget.value = ""
      
      const isValid = controller.validateForm()
      expect(isValid).toBeFalsy()
    })

    it("returns true for valid simple location", () => {
      const nameInput = document.getElementById("location_name")
      nameInput.value = "Test Location"
      
      const isValid = controller.validateForm()
      expect(isValid).toBeTruthy()
    })

    it("returns true for valid structured location", () => {
      controller.locationModeToggleTarget.checked = true
      controller.toggleLocationMode()
      
      controller.locationTypeSelectTarget.value = "BetterTogether::Geography::Address"
      controller.locationSelectTarget.value = "123"
      
      const isValid = controller.validateForm()
      expect(isValid).toBeTruthy()
    })
  })

  describe("accessibility", () => {
    it("updates ARIA attributes when switching modes", () => {
      controller.locationModeToggleTarget.checked = true
      controller.toggleLocationMode()

      expect(controller.simpleLocationFieldsTarget.getAttribute("aria-hidden")).toBe("true")
      expect(controller.structuredLocationFieldsTarget.getAttribute("aria-hidden")).toBe("false")
    })

    it("maintains focus management during mode switches", () => {
      const nameInput = document.getElementById("location_name")
      nameInput.focus()
      
      controller.locationModeToggleTarget.checked = true
      controller.toggleLocationMode()

      expect(document.activeElement).toBe(controller.locationTypeSelectTarget)
    })
  })
})
