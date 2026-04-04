import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "selectorInput",
    "videoSource",
    "videoTimestamp",
    "imageSource",
    "regionX",
    "regionY",
    "regionWidth",
    "regionHeight"
  ]

  connect() {
    this.hydrateHelpersFromSelector()
  }

  composeVideoSelector() {
    if (!this.hasVideoSourceTarget || !this.hasVideoTimestampTarget) return

    const source = this.videoSourceTarget.value
    const timestamp = this.normalizeTimestamp(this.videoTimestampTarget.value)
    if (!source || !timestamp) return

    this.selectorInputTarget.value = source.replace(/:video$/, `:timestamp:${timestamp}`)
  }

  composeImageSelector() {
    if (!this.hasImageSourceTarget) return

    const source = this.imageSourceTarget.value
    const values = [
      this.regionXTarget?.value,
      this.regionYTarget?.value,
      this.regionWidthTarget?.value,
      this.regionHeightTarget?.value
    ].map((value) => value?.toString().trim())

    if (!source || values.some((value) => !value)) return

    const [x, y, width, height] = values
    this.selectorInputTarget.value = source.replace(/:media$/, `:region:x=${x},y=${y},w=${width},h=${height}`)
  }

  hydrateHelpersFromSelector() {
    if (!this.hasSelectorInputTarget) return

    const selector = this.selectorInputTarget.value?.trim()
    if (!selector) return

    const timestampMatch = selector.match(/^(.*):timestamp:([0-9]{2}:[0-9]{2}:[0-9]{2})$/)
    if (timestampMatch && this.hasVideoSourceTarget && this.hasVideoTimestampTarget) {
      this.videoSourceTarget.value = `${timestampMatch[1]}:video`
      this.videoTimestampTarget.value = timestampMatch[2]
    }

    const regionMatch = selector.match(/^(.*):region:x=(\d+),y=(\d+),w=(\d+),h=(\d+)$/)
    if (regionMatch && this.hasImageSourceTarget) {
      this.imageSourceTarget.value = `${regionMatch[1]}:media`
      if (this.hasRegionXTarget) this.regionXTarget.value = regionMatch[2]
      if (this.hasRegionYTarget) this.regionYTarget.value = regionMatch[3]
      if (this.hasRegionWidthTarget) this.regionWidthTarget.value = regionMatch[4]
      if (this.hasRegionHeightTarget) this.regionHeightTarget.value = regionMatch[5]
    }
  }

  normalizeTimestamp(rawValue) {
    const value = rawValue?.trim()
    if (!value) return null

    if (/^\d{2}:\d{2}:\d{2}$/.test(value)) return value

    if (/^\d+$/.test(value)) {
      const totalSeconds = parseInt(value, 10)
      const hours = Math.floor(totalSeconds / 3600)
      const minutes = Math.floor((totalSeconds % 3600) / 60)
      const seconds = totalSeconds % 60

      return [hours, minutes, seconds].map((part) => part.toString().padStart(2, "0")).join(":")
    }

    return null
  }
}
