// Draws a map pin from its data ({ color, shape, size, icons }), as DOM nodes rather than HTML strings so nothing in
// the data can become markup. The server validates the same fields (BetterTogether::Geography::MapPin); this checks
// them again because pins can also reach the controller through other data attributes.
const SIZES = { sm: 24, md: 30, lg: 38 }
const SHAPES = ['circle', 'rounded', 'square']
const STYLES = ['fas', 'far', 'fab', 'fa-solid', 'fa-regular', 'fa-brands']
const ICON = /^fa-[a-z0-9]+(?:-[a-z0-9]+)*$/
const DEFAULT_COLOR = '#6c757d'
const DEFAULT_ICON = 'fa-location-dot'

function safeColor (value, fallback) {
  return value && window.CSS?.supports?.('color', value) ? value : fallback
}

function iconNode (entry, stacked, base) {
  const spec = typeof entry === 'string' ? { icon: entry } : entry
  if (!ICON.test(spec.icon || '')) return null

  const node = document.createElement('i')
  node.classList.add(STYLES.includes(spec.style) ? spec.style : 'fas', spec.icon)
  if (stacked) node.classList.add(base ? 'fa-stack-2x' : 'fa-stack-1x')
  const color = safeColor(spec.color, null)
  if (color) node.style.color = color
  if (spec.scale >= 0.3 && spec.scale <= 1.5) node.style.fontSize = `${spec.scale}em`
  node.setAttribute('aria-hidden', 'true')
  return node
}

// A pin from the point's own pin, else its legacy color and icon keys.
export function pinFrom (point, typePin) {
  const own = point.pin || { color: point.color, icons: point.icon ? [point.icon] : [] }
  const merged = { ...(typePin || {}) }
  Object.entries(own).forEach(([key, value]) => {
    if (value !== undefined && value !== null && !(Array.isArray(value) && value.length === 0)) merged[key] = value
  })
  return merged
}

export function pinElement (pin) {
  const size = SIZES[pin.size] || SIZES.md
  const span = document.createElement('span')
  span.classList.add(`map-pin-${SHAPES.includes(pin.shape) ? pin.shape : 'circle'}`)
  span.style.background = safeColor(pin.color, DEFAULT_COLOR)
  span.style.width = span.style.height = `${size}px`

  const names = (pin.icons && pin.icons.length ? pin.icons : [DEFAULT_ICON]).slice(0, 4)
  const stacked = names.length > 1
  const nodes = names.map((entry, index) => iconNode(entry, stacked, index === 0)).filter(Boolean)
  if (stacked && nodes.length > 1) {
    const stack = document.createElement('span')
    stack.classList.add('fa-stack')
    stack.style.fontSize = `${Math.round(size * 0.45)}px`
    nodes.forEach((node) => stack.appendChild(node))
    span.appendChild(stack)
  } else {
    span.style.fontSize = `${Math.round(size * 0.45)}px`
    span.appendChild(nodes[0] || iconNode(DEFAULT_ICON, false, true))
  }
  return { element: span, size }
}

export function pinIcon (L, pin) {
  const { element, size } = pinElement(pin)
  return L.divIcon({ className: 'map-pin', html: element, iconSize: [size, size], iconAnchor: [size / 2, size / 2] })
}
