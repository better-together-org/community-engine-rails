import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "container",
    "template",
    "entry",
    "contributorTypeRadio",
    "contributorSelect",
    "authorTypeInput",
    "removeButton"
  ]

  static values = {
    personOptions: Array,
    robotOptions: Array,
    selectPlaceholder: String
  }

  connect() {
    this.initializeEntries()
  }

  add(event) {
    event.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
    this.containerTarget.insertAdjacentHTML("beforeend", content)

    const entries = this.containerTarget.querySelectorAll('[data-better_together--contribution-assignments-target="entry"]')
    const latestEntry = entries[entries.length - 1]
    if (latestEntry) {
      this.initializeEntry(latestEntry, false)

      const firstRadio = latestEntry.querySelector('[data-better_together--contribution-assignments-target="contributorTypeRadio"]')
      firstRadio?.focus()
    }
  }

  remove(event) {
    event.preventDefault()

    const entry = event.target.closest('.nested-fields')
    if (!entry) return

    if (entry.dataset.newRecord === "true") {
      entry.remove()
      return
    }

    const destroyInput = entry.querySelector('input[name*="[_destroy]"]')
    if (destroyInput) {
      destroyInput.value = "1"
      entry.style.display = "none"
    }
  }

  contributorTypeChanged(event) {
    const entry = event.target.closest('.nested-fields')
    if (!entry) return

    this.initializeEntry(entry, false)
  }

  initializeEntries() {
    this.entryTargets.forEach((entry) => this.initializeEntry(entry, true))
  }

  initializeEntry(entry, preserveSelection) {
    const checkedRadio = entry.querySelector('[data-better_together--contribution-assignments-target="contributorTypeRadio"]:checked')
    const firstRadio = entry.querySelector('[data-better_together--contribution-assignments-target="contributorTypeRadio"]')
    const activeRadio = checkedRadio || firstRadio
    if (!activeRadio) return

    activeRadio.checked = true

    const authorTypeInput = entry.querySelector('[data-better_together--contribution-assignments-target="authorTypeInput"]')
    const contributorSelect = entry.querySelector('[data-better_together--contribution-assignments-target="contributorSelect"]')
    if (!authorTypeInput || !contributorSelect) return

    authorTypeInput.value = activeRadio.value

    const selectedValue = preserveSelection ? contributorSelect.value : ""
    this.populateContributorOptions(contributorSelect, activeRadio.value, selectedValue)
  }

  populateContributorOptions(select, contributorType, selectedValue) {
    const options = contributorType === "BetterTogether::Robot" ? this.robotOptionsValue : this.personOptionsValue

    select.innerHTML = ""

    const placeholder = document.createElement("option")
    placeholder.value = ""
    placeholder.textContent = this.selectPlaceholderValue || "Select contributor"
    select.appendChild(placeholder)

    options.forEach((optionData) => {
      const option = document.createElement("option")
      option.value = optionData.value
      option.textContent = optionData.text
      select.appendChild(option)
    })

    const matchingOption = options.find((optionData) => optionData.value === selectedValue)
    select.value = matchingOption ? selectedValue : ""
  }
}
