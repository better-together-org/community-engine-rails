// Keeps the platform and personal theme <style> elements in step with the server and in cascade order:
// platform theme, then personal theme, then the platform Css block, which must be able to override both.

export const THEME_STYLE_IDS = ["platform-theme-style", "user-theme-style"]
const HTML_ATTRIBUTES = ["data-bts-color-mode", "data-bts-user-mode", "data-bts-user-theme"]

function cssBlock(root) {
  return (root.head || root).querySelector("style[data-bts-css-block]")
}

// Moves the theme styles back in front of the Css block. Turbo appends a changed style to the end of <head>.
export function orderThemeStyles(root = document) {
  const block = cssBlock(root)
  if (!block) return
  THEME_STYLE_IDS.forEach((id) => {
    const style = root.getElementById(id)
    if (style && (style.compareDocumentPosition(block) & Node.DOCUMENT_POSITION_PRECEDING)) block.before(style)
  })
}

function copyStyle(source) {
  const style = document.createElement("style")
  Array.from(source.attributes).forEach((attr) => style.setAttribute(attr.name, attr.value))
  style.textContent = source.textContent
  return style
}

// Replaces, adds or removes each theme style so the page matches +doc+ (a freshly fetched copy of it).
export function syncThemeStyles(doc) {
  THEME_STYLE_IDS.forEach((id) => {
    const fresh = doc.getElementById(id)
    const current = document.getElementById(id)
    if (!fresh) { if (current) current.remove(); return }
    if (current && current.textContent === fresh.textContent) return

    const style = copyStyle(fresh)
    if (current) { current.replaceWith(style); return }
    const later = THEME_STYLE_IDS.slice(THEME_STYLE_IDS.indexOf(id) + 1).map((next) => document.getElementById(next)).find(Boolean)
    const anchor = later || cssBlock(document)
    anchor ? anchor.before(style) : document.head.appendChild(style)
  })
  HTML_ATTRIBUTES.forEach((name) => {
    const value = doc.documentElement.getAttribute(name)
    value === null ? document.documentElement.removeAttribute(name) : document.documentElement.setAttribute(name, value)
  })
  const scheme = doc.querySelector('meta[name="color-scheme"]')
  const currentScheme = document.querySelector('meta[name="color-scheme"]')
  if (scheme && currentScheme) currentScheme.setAttribute("content", scheme.getAttribute("content"))
}

document.addEventListener("turbo:render", () => orderThemeStyles())
