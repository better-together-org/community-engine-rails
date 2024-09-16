import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pageBlock", "position"]

  moveUp(event) {
    event.preventDefault()

    const currentBlock = event.target.closest(".page-block-fields")
    const previousBlock = currentBlock.previousElementSibling

    if (previousBlock && previousBlock.classList.contains("page-block-fields")) {
      currentBlock.parentNode.insertBefore(currentBlock, previousBlock)
      this.updatePageBlockPositions()
      this.scrollToPageBlock(currentBlock)
    }
  }

  moveDown(event) {
    event.preventDefault()

    const currentBlock = event.target.closest(".page-block-fields")
    const nextBlock = currentBlock.nextElementSibling

    if (nextBlock && nextBlock.classList.contains("page-block-fields")) {
      currentBlock.parentNode.insertBefore(nextBlock, currentBlock)
      this.updatePageBlockPositions()
      this.scrollToPageBlock(currentBlock)
    }
  }

  updatePageBlockPositions() {
    this.pageBlockTargets.forEach((block, index) => {
      const positionInput = block.querySelector("input[data-page-blocks-target='position']")
      positionInput.value = index + 1
    })
  }

  scrollToPageBlock(block) {
    block.scrollIntoView({
      behavior: "smooth",
      block: "center"
    })
  }
}
