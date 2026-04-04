import 'trix'

// Run the function on initial page load
document.addEventListener('DOMContentLoaded', initializeRichText);

// Run the function after Turbo finishes loading new content

document.addEventListener("turbo:load", initializeRichText);

function initializeRichText() {
  // Ensure attributes are only added once
  if (!window.headingAttributesAdded) {
    addHeadingAttributes()
    addForegroundColorAttributes()
    addBackgroundColorAttributes()

    window.addEventListener("trix-file-accept", function(event) {
      const acceptedTypes = ['image/jpeg', 'image/png']
      if (!acceptedTypes.includes(event.file.type)) {
        event.preventDefault()
        alert("Only support attachment of jpeg or png files")
      }
    })
    window.headingAttributesAdded = true; // Flag to prevent re-adding
  }

  // Only add event listeners once
  document.removeEventListener("trix-initialize", initializeTrixEditor);
  document.addEventListener("trix-initialize", initializeTrixEditor);

  document.removeEventListener("trix-action-invoke", handleTrixAction);
  document.addEventListener("trix-action-invoke", handleTrixAction);
}

function initializeTrixEditor(event) {
  if (!event.target.hasInitializedRichText) {
    new RichText(event.target);
    event.target.hasInitializedRichText = true; // Flag to prevent re-initializing
  }
}

function handleTrixAction(event) {
  if (event.actionName === "x-horizontal-rule") {
    insertHorizontalRule(event);
  } else if (event.actionName === "x-citation") {
    event.preventDefault();
    const richText = event.target.richTextExtension;
    if (richText) richText.openCitationDialog();
  }
}

function insertHorizontalRule(event) {
  event.target.editor.insertAttachment(buildHorizontalRule());
}

function buildHorizontalRule() {
  return new Trix.Attachment({
    content: "<hr>",
    contentType: "vnd.rubyonrails.horizontal-rule.html"
  });
}

class RichText {
  constructor(element) {
    this.element = element;
    this.element.richTextExtension = this;
    this.insertHeadingElements();
    this.insertDividerElements();
    this.insertColorElements();
    this.insertCitationElements();
  }

  insertHeadingElements() {
    this.removeOriginalHeadingButton();
    if (!this.toolbarElement.querySelector('.trix-button--icon-heading-1')) {
      this.insertNewHeadingButton();
      this.insertHeadingDialog();
    }
  }

  removeOriginalHeadingButton() {
    const originalHeadingButton = this.originalHeadingButton;
    if (originalHeadingButton && this.buttonGroupBlockTools.contains(originalHeadingButton)) {
      this.buttonGroupBlockTools.removeChild(originalHeadingButton);
    }
  }

  insertNewHeadingButton() {
    this.buttonGroupBlockTools.insertAdjacentHTML("afterbegin", this.headingButtonTemplate);
  }

  insertHeadingDialog() {
    if (!this.dialogsElement.querySelector('.trix-dialog--heading')) {
      this.dialogsElement.insertAdjacentHTML("beforeend", this.dialogHeadingTemplate);
    }
  }

  insertDividerElements() {
    if (!this.toolbarElement.querySelector('.trix-button--icon-horizontal-rule')) {
      this.quoteButton.insertAdjacentHTML("afterend", this.horizontalButtonTemplate);
    }
  }

  insertColorElements() {
    if (!this.toolbarElement.querySelector('.trix-button--icon-color')) {
      this.insertColorButton();
      this.insertDialogColor();
    }
  }

  insertColorButton() {
    this.buttonGroupTextTools.insertAdjacentHTML("beforeend", this.colorButtonTemplate);
  }

  insertDialogColor() {
    if (!this.dialogsElement.querySelector('.trix-dialog--color')) {
      this.dialogsElement.insertAdjacentHTML("beforeend", this.dialogColorTemplate);
    }
  }

  insertCitationElements() {
    if (!this.toolbarElement.querySelector('.trix-button--icon-citation')) {
      this.buttonGroupTextTools.insertAdjacentHTML("beforeend", this.citationButtonTemplate);
    }

    if (!this.dialogsElement.querySelector('.trix-dialog--citation')) {
      this.dialogsElement.insertAdjacentHTML("beforeend", this.dialogCitationTemplate);
      this.bindCitationDialog();
    }
  }

  bindCitationDialog() {
    const insertButton = this.dialogsElement.querySelector('.trix-dialog--citation-insert');
    const cancelButton = this.dialogsElement.querySelector('.trix-dialog--citation-cancel');

    insertButton?.addEventListener('click', (event) => {
      event.preventDefault();
      this.insertCitationFromDialog();
    });

    cancelButton?.addEventListener('click', (event) => {
      event.preventDefault();
      this.closeCitationDialog();
    });
  }

  openCitationDialog() {
    const dialog = this.citationDialogElement;
    if (!dialog) return;

    this.populateCitationOptions();
    dialog.style.display = 'block';
    this.citationSelectElement?.focus();
  }

  closeCitationDialog() {
    if (!this.citationDialogElement) return;

    this.citationDialogElement.style.display = 'none';
    if (this.citationSelectElement) this.citationSelectElement.selectedIndex = 0;
    if (this.citationLocatorElement) this.citationLocatorElement.value = '';
  }

  populateCitationOptions() {
    if (!this.citationSelectElement) return;

    const options = this.citationOptions;
    const currentValue = this.citationSelectElement.value;
    const optionMarkup = ['<option value="">Select citation</option>']
      .concat(options.map((option) => `<option value="${escapeHtml(option.referenceKey)}">${escapeHtml(option.label)}</option>`))
      .join('');

    this.citationSelectElement.innerHTML = optionMarkup;
    if (currentValue) this.citationSelectElement.value = currentValue;
  }

  insertCitationFromDialog() {
    const referenceKey = this.citationSelectElement?.value;
    if (!referenceKey) return;

    const locator = this.citationLocatorElement?.value?.trim();
    const href = `#citation-${referenceKey}`;
    const selectedText = this.selectedText();

    if (selectedText) {
      this.element.editor.insertHTML(`<a href="${href}" class="citation-link" data-citation-key="${escapeHtml(referenceKey)}">${escapeHtml(selectedText)}</a>`);
    } else {
      const label = locator ? `${referenceKey}, ${locator}` : referenceKey;
      this.element.editor.insertHTML(`<sup class="citation-reference"><a href="${href}" class="citation-link" data-citation-key="${escapeHtml(referenceKey)}">[${escapeHtml(label)}]</a></sup>`);
    }

    this.closeCitationDialog();
  }

  selectedText() {
    const range = this.element.editor.getSelectedRange();
    if (!range || range[0] === range[1]) return '';

    return this.element.editor.getDocument().toString().slice(range[0], range[1]).trim();
  }

  get buttonGroupBlockTools() {
    return this.toolbarElement.querySelector("[data-trix-button-group=block-tools]");
  }

  get buttonGroupTextTools() {
    return this.toolbarElement.querySelector("[data-trix-button-group=text-tools]");
  }

  get dialogsElement() {
    return this.toolbarElement.querySelector("[data-trix-dialogs]");
  }

  get citationDialogElement() {
    return this.dialogsElement.querySelector('.trix-dialog--citation');
  }

  get citationSelectElement() {
    return this.dialogsElement.querySelector('[data-trix-citation-select]');
  }

  get citationLocatorElement() {
    return this.dialogsElement.querySelector('[data-trix-citation-locator]');
  }

  get citationOptions() {
    const raw = this.element.dataset.citationOptions;
    if (!raw) return [];

    try {
      return JSON.parse(raw);
    } catch (_error) {
      return [];
    }
  }

  get originalHeadingButton() {
    return this.toolbarElement.querySelector("[data-trix-attribute=heading1]");
  }

  get quoteButton() {
    return this.toolbarElement.querySelector("[data-trix-attribute=quote]");
  }

  get toolbarElement() {
    return this.element.toolbarElement;
  }

  get horizontalButtonTemplate() {
    return '<button type="button" class="trix-button trix-button--icon trix-button--icon-horizontal-rule" data-trix-action="x-horizontal-rule" tabindex="-1" title="Divider">Divider</button>';
  }

  get headingButtonTemplate() {
    return '<button type="button" class="trix-button trix-button--icon trix-button--icon-heading-1" data-trix-action="x-heading" title="Heading" tabindex="-1">Heading</button>';
  }

  get colorButtonTemplate() {
    return '<button type="button" class="trix-button trix-button--icon trix-button--icon-color" data-trix-action="x-color" title="Color" tabindex="-1">Color</button>';
  }

  get citationButtonTemplate() {
    return '<button type="button" class="trix-button trix-button--icon trix-button--icon-citation" data-trix-action="x-citation" title="Citation" tabindex="-1">Citation</button>';
  }

  get dialogHeadingTemplate() {
    return `
      <div class="trix-dialog trix-dialog--heading" data-trix-dialog="x-heading" data-trix-dialog-attribute="x-heading">
        <div class="trix-dialog__link-fields">
          <input type="text" name="x-heading" class="trix-dialog-hidden__input" data-trix-input>
          <div class="trix-button-group">
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading1">H1</button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading2">H2</button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading3">H3</button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading4">H4</button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading5">H5</button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading6">H6</button>
          </div>
        </div>
      </div>
    `;
  }

  get dialogColorTemplate() {
    return `
      <div class="trix-dialog trix-dialog--color" data-trix-dialog="x-color" data-trix-dialog-attribute="x-color">
        <div class="trix-dialog__link-fields">
          <input type="text" name="x-color" class="trix-dialog-hidden__input" data-trix-input>
          <div class="trix-button-group">
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor1"></button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor2"></button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor3"></button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor4"></button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor5"></button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor6"></button>
          </div>
          <div class="trix-button-group">
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor1"></button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor2"></button>
            <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor3"></button>
          </div>
        </div>
      </div>
    `;
  }

  get dialogCitationTemplate() {
    return `
      <div class="trix-dialog trix-dialog--citation" data-trix-dialog="x-citation" style="display:none;">
        <div class="trix-dialog__link-fields">
          <label class="trix-label" for="trix-citation-select">Citation</label>
          <select id="trix-citation-select" class="trix-input trix-input--dialog" data-trix-citation-select></select>
          <label class="trix-label" for="trix-citation-locator">Locator</label>
          <input id="trix-citation-locator" type="text" class="trix-input trix-input--dialog" data-trix-citation-locator placeholder="Optional page, figure, timestamp">
          <div class="trix-button-group mt-2">
            <button type="button" class="trix-button trix-button--dialog trix-dialog--citation-insert">Insert</button>
            <button type="button" class="trix-button trix-button--dialog trix-dialog--citation-cancel">Cancel</button>
          </div>
        </div>
      </div>
    `;
  }
}

function escapeHtml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function addHeadingAttributes() {
  Array.from(["h1", "h2", "h3", "h4", "h5", "h6"]).forEach((tagName, i) => {
    Trix.config.blockAttributes[`heading${i + 1}`] = { tagName: tagName, terminal: true, breakOnReturn: true, group: false };
  });
}

function addForegroundColorAttributes() {
  Array.from(["rgb(136, 118, 38)", "rgb(185, 94, 6)", "rgb(207, 0, 0)"]).forEach((color, i) => {
    Trix.config.textAttributes[`fgColor${i + 1}`] = { style: { color: color }, inheritable: true, parser: e => e.style.color == color };
  });
}

function addBackgroundColorAttributes() {
  Array.from(["rgb(250, 247, 133)", "rgb(255, 240, 219)", "rgb(255, 229, 229)"]).forEach((color, i) => {
    Trix.config.textAttributes[`bgColor${i + 1}`] = { style: { backgroundColor: color }, inheritable: true, parser: e => e.style.backgroundColor == color };
  });
}
