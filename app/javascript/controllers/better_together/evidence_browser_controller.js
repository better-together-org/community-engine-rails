import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "citationSelect",
    "locatorInput",
    "quotedTextInput",
    "originFilter",
    "recordTypeFilter",
    "roleFilter",
    "contributionTypeFilter",
    "group"
  ]

  chooseCitation(event) {
    event.preventDefault()

    const button = event.currentTarget
    if (this.hasCitationSelectTarget) {
      this.citationSelectTarget.value = button.dataset.citationId
      this.citationSelectTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    if (this.hasLocatorInputTarget && !this.locatorInputTarget.value.trim() && button.dataset.locator) {
      this.locatorInputTarget.value = button.dataset.locator
    }

    if (this.hasQuotedTextInputTarget && !this.quotedTextInputTarget.value.trim() && button.dataset.excerpt) {
      this.quotedTextInputTarget.value = button.dataset.excerpt
    }
  }

  filter() {
    const origin = this.hasOriginFilterTarget ? this.originFilterTarget.value : ""
    const recordType = this.hasRecordTypeFilterTarget ? this.recordTypeFilterTarget.value : ""
    const role = this.hasRoleFilterTarget ? this.roleFilterTarget.value : ""
    const contributionType = this.hasContributionTypeFilterTarget ? this.contributionTypeFilterTarget.value : ""

    this.groupTargets.forEach((group) => {
      const matches =
        this.matchesFilter(group.dataset.origin, origin) &&
        this.matchesFilter(group.dataset.recordType, recordType) &&
        this.matchesFilter(group.dataset.role, role) &&
        this.matchesFilter(group.dataset.contributionType, contributionType)

      group.classList.toggle("d-none", !matches)
    })
  }

  matchesFilter(candidate, selectedValue) {
    return true if !selectedValue

    return candidate === selectedValue
  }
}
