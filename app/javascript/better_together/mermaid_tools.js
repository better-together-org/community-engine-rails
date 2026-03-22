// Shared helpers to enhance Mermaid diagrams with zoom/pan controls and drag-to-pan viewport
export function enhanceDiagrams(diagrams) {
  diagrams.forEach((diagram) => {
    if (diagram.dataset.enhanced === 'true') return
    const svg = diagram.querySelector('svg')
    if (!svg) return

    // Normalize container so pre/code defaults do not affect layout
    diagram.style.backgroundColor = 'transparent'
    diagram.style.border = 'none'
    diagram.style.padding = '0'
    diagram.style.margin = '0'
    diagram.style.fontFamily = 'inherit'
    diagram.style.whiteSpace = 'normal'
    diagram.style.color = 'inherit'

    const { controls, viewport } = buildScaffold()

    svg.style.display = 'block'
    svg.style.transformOrigin = 'top left'

    const state = { scale: 1 }
    const applyScale = () => {
      svg.style.transform = `scale(${state.scale})`
    }

    const zoomIn = () => {
      state.scale = Math.min(3, state.scale + 0.1)
      applyScale()
    }

    const zoomOut = () => {
      state.scale = Math.max(0.2, state.scale - 0.1)
      applyScale()
    }

    const reset = () => {
      state.scale = 1
      applyScale()
      viewport.scrollLeft = 0
      viewport.scrollTop = 0
    }

    const panBy = (dx, dy) => {
      viewport.scrollLeft += dx
      viewport.scrollTop += dy
    }

    const downloadMmd = () => {
      const source = diagram.dataset.originalContent || svg.parentElement?.dataset?.originalContent || ''
      downloadFile(source, 'diagram.mmd', 'text/plain')
    }

    const downloadPng = () => {
      svgToImage(svg, 'png', (dataUrl) => {
        downloadFile(dataUrl, 'diagram.png', 'image/png', true)
      })
    }

    const downloadJpg = () => {
      svgToImage(svg, 'jpeg', (dataUrl) => {
        downloadFile(dataUrl, 'diagram.jpg', 'image/jpeg', true)
      })
    }

    const enterFullscreen = () => {
      const container = diagram
      const fullscreenOverlay = createFullscreenOverlay(container, viewport, controls, exitFullscreen, state, applyScale, { zoomIn, zoomOut, reset, panBy, downloadMmd, downloadPng, downloadJpg })
      document.body.appendChild(fullscreenOverlay)
      document.body.style.overflow = 'hidden'
    }

    const exitFullscreen = () => {
      const overlay = document.querySelector('.mermaid-fullscreen-overlay')
      if (overlay) {
        // Move viewport and controls back to original diagram container
        const svg = overlay.querySelector('svg')
        if (svg) {
          viewport.appendChild(svg)
        }
        diagram.appendChild(viewport)
        diagram.appendChild(controls)
        document.body.removeChild(overlay)
        document.body.style.overflow = ''
      }
    }

    applyScale()

    controls.querySelector('[data-mermaid-fullscreen]').addEventListener('click', enterFullscreen)
    controls.querySelector('[data-mermaid-zoom="in"]').addEventListener('click', zoomIn)
    controls.querySelector('[data-mermaid-zoom="out"]').addEventListener('click', zoomOut)
    controls.querySelector('[data-mermaid-zoom="reset"]').addEventListener('click', reset)
    controls.querySelector('[data-mermaid-pan="left"]').addEventListener('click', () => panBy(-80, 0))
    controls.querySelector('[data-mermaid-pan="right"]').addEventListener('click', () => panBy(80, 0))
    controls.querySelector('[data-mermaid-pan="up"]').addEventListener('click', () => panBy(0, -80))
    controls.querySelector('[data-mermaid-pan="down"]').addEventListener('click', () => panBy(0, 80))
    controls.querySelector('[data-mermaid-download="mmd"]').addEventListener('click', (e) => { e.preventDefault(); downloadMmd() })
    controls.querySelector('[data-mermaid-download="png"]').addEventListener('click', (e) => { e.preventDefault(); downloadPng() })
    controls.querySelector('[data-mermaid-download="jpg"]').addEventListener('click', (e) => { e.preventDefault(); downloadJpg() })

    attachDragPan(viewport)

    viewport.appendChild(svg)
    diagram.innerHTML = ''
    diagram.appendChild(viewport)
    diagram.appendChild(controls)
    diagram.dataset.enhanced = 'true'
  })
}

function buildScaffold() {
  const viewport = document.createElement('div')
  viewport.className = 'mermaid-viewport'
  viewport.style.overflow = 'auto'
  viewport.style.maxHeight = '480px'
  viewport.style.border = '1px solid rgba(0,0,0,0.05)'
  viewport.style.borderRadius = '0.25rem'
  viewport.style.padding = '0.5rem'
  viewport.style.backgroundColor = '#fff'
  viewport.style.cursor = 'grab'

  const controls = document.createElement('div')
  controls.className = 'btn-toolbar justify-content-center gap-2 mt-2'

  const fullscreenGroup = document.createElement('div')
  fullscreenGroup.className = 'btn-group btn-group-sm'
  fullscreenGroup.role = 'group'
  fullscreenGroup.ariaLabel = 'Fullscreen controls'
  fullscreenGroup.innerHTML = `
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1" data-mermaid-fullscreen aria-label="Enter fullscreen">
      <i class="fas fa-expand" aria-hidden="true"></i>
    </button>
  `

  const zoomGroup = document.createElement('div')
  zoomGroup.className = 'btn-group btn-group-sm'
  zoomGroup.role = 'group'
  zoomGroup.ariaLabel = 'Zoom controls'
  zoomGroup.innerHTML = `
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1" data-mermaid-zoom="in" aria-label="Zoom in">+
    </button>
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1" data-mermaid-zoom="out" aria-label="Zoom out">−
    </button>
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1" data-mermaid-zoom="reset" aria-label="Reset zoom">⟳
    </button>
  `

  const panGroup = document.createElement('div')
  panGroup.className = 'btn-group btn-group-sm'
  panGroup.role = 'group'
  panGroup.ariaLabel = 'Pan controls'
  panGroup.innerHTML = `
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1" data-mermaid-pan="up" aria-label="Pan up">↑</button>
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1" data-mermaid-pan="left" aria-label="Pan left">←</button>
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1" data-mermaid-pan="right" aria-label="Pan right">→</button>
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1" data-mermaid-pan="down" aria-label="Pan down">↓</button>
  `

  const downloadGroup = document.createElement('div')
  downloadGroup.className = 'btn-group btn-group-sm'
  downloadGroup.role = 'group'
  downloadGroup.ariaLabel = 'Download controls'
  downloadGroup.innerHTML = `
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1 dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false" aria-label="Download diagram">
      <i class="fas fa-download" aria-hidden="true"></i>
    </button>
    <ul class="dropdown-menu">
      <li><button type="button" class="dropdown-item" data-mermaid-download="mmd">Download .mmd</button></li>
      <li><button type="button" class="dropdown-item" data-mermaid-download="png">Download .png</button></li>
      <li><button type="button" class="dropdown-item" data-mermaid-download="jpg">Download .jpg</button></li>
    </ul>
  `

  controls.appendChild(fullscreenGroup)
  controls.appendChild(zoomGroup)
  controls.appendChild(panGroup)
  controls.appendChild(downloadGroup)

  return { controls, viewport }
}

function attachDragPan(viewport) {
  let isDragging = false
  let startX = 0
  let startY = 0
  let startScrollLeft = 0
  let startScrollTop = 0

  const onPointerDown = (event) => {
    isDragging = true
    startX = event.clientX
    startY = event.clientY
    startScrollLeft = viewport.scrollLeft
    startScrollTop = viewport.scrollTop
    viewport.setPointerCapture(event.pointerId)
    viewport.style.cursor = 'grabbing'
  }

  const onPointerMove = (event) => {
    if (!isDragging) return
    const dx = event.clientX - startX
    const dy = event.clientY - startY
    viewport.scrollLeft = startScrollLeft - dx
    viewport.scrollTop = startScrollTop - dy
  }

  const endDrag = (event) => {
    if (!isDragging) return
    isDragging = false
    viewport.releasePointerCapture(event.pointerId)
    viewport.style.cursor = 'grab'
  }

  viewport.addEventListener('pointerdown', onPointerDown)
  viewport.addEventListener('pointermove', onPointerMove)
  viewport.addEventListener('pointerup', endDrag)
  viewport.addEventListener('pointercancel', endDrag)
  viewport.addEventListener('pointerleave', endDrag)
}

function downloadFile(content, filename, mimeType, isDataUrl = false) {
  const link = document.createElement('a')
  link.download = filename
  
  if (isDataUrl) {
    // Convert data URL to blob to avoid "Not allowed to navigate top frame to data URL" error
    const byteString = atob(content.split(',')[1])
    const mimeString = content.split(',')[0].split(':')[1].split(';')[0]
    const arrayBuffer = new ArrayBuffer(byteString.length)
    const uint8Array = new Uint8Array(arrayBuffer)
    
    for (let i = 0; i < byteString.length; i++) {
      uint8Array[i] = byteString.charCodeAt(i)
    }
    
    const blob = new Blob([arrayBuffer], { type: mimeString })
    link.href = URL.createObjectURL(blob)
  } else {
    const blob = new Blob([content], { type: mimeType })
    link.href = URL.createObjectURL(blob)
  }
  
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  
  // Always revoke object URL to prevent memory leaks
  setTimeout(() => URL.revokeObjectURL(link.href), 100)
}

function svgToImage(svg, format, callback) {
  const svgData = new XMLSerializer().serializeToString(svg)
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')
  const img = new Image()

  // Get SVG dimensions
  const bbox = svg.getBBox()
  const width = bbox.width || svg.viewBox.baseVal.width || 800
  const height = bbox.height || svg.viewBox.baseVal.height || 600

  // Set canvas size with scale for better quality
  const scale = 2
  canvas.width = width * scale
  canvas.height = height * scale
  ctx.scale(scale, scale)

  // Fill white background for JPG
  if (format === 'jpeg') {
    ctx.fillStyle = '#ffffff'
    ctx.fillRect(0, 0, width, height)
  }

  img.onload = () => {
    ctx.drawImage(img, 0, 0, width, height)
    const dataUrl = canvas.toDataURL(`image/${format}`, 0.95)
    callback(dataUrl)
  }

  img.onerror = (error) => {
    console.error('Failed to convert SVG to image:', error)
    alert('Failed to download image. Please try again.')
  }

  // Use data URL instead of blob URL to avoid CORS/tainted canvas issues
  const svgData64 = btoa(unescape(encodeURIComponent(svgData)))
  img.src = `data:image/svg+xml;base64,${svgData64}`
}

function createFullscreenOverlay(originalContainer, viewport, controls, exitCallback, state, applyScale, handlers) {
  const overlay = document.createElement('div')
  overlay.className = 'mermaid-fullscreen-overlay'
  overlay.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background-color: rgba(0, 0, 0, 0.95);
    z-index: 9999;
    display: flex;
    flex-direction: column;
    padding: 1rem;
  `

  const closeButton = document.createElement('button')
  closeButton.type = 'button'
  closeButton.className = 'btn btn-dark btn-sm'
  closeButton.innerHTML = '<i class="fas fa-times" aria-hidden="true"></i> Close'
  closeButton.setAttribute('aria-label', 'Exit fullscreen')
  closeButton.style.cssText = `
    position: absolute;
    top: 1rem;
    right: 1rem;
    z-index: 10000;
  `
  closeButton.addEventListener('click', exitCallback)

  const fullscreenViewport = document.createElement('div')
  fullscreenViewport.className = 'mermaid-viewport'
  fullscreenViewport.style.cssText = `
    flex: 1;
    overflow: auto;
    max-height: none;
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 0.25rem;
    padding: 0.5rem;
    background-color: #fff;
    cursor: grab;
    margin-bottom: 1rem;
  `

  // Move SVG to fullscreen viewport
  const svg = viewport.querySelector('svg')
  if (svg) {
    fullscreenViewport.appendChild(svg)
  }

  // Clone controls for fullscreen
  const fullscreenControls = document.createElement('div')
  fullscreenControls.className = 'btn-toolbar justify-content-center gap-2 mt-2'

  // Recreate button groups with handlers
  const fullscreenGroup = createButtonGroup('Fullscreen controls', [
    { icon: 'fa-compress', label: 'Exit fullscreen', handler: exitCallback, attr: 'data-mermaid-fullscreen' }
  ])

  const zoomGroup = createButtonGroup('Zoom controls', [
    { text: '+', label: 'Zoom in', handler: handlers.zoomIn, attr: 'data-mermaid-zoom="in"' },
    { text: '−', label: 'Zoom out', handler: handlers.zoomOut, attr: 'data-mermaid-zoom="out"' },
    { text: '⟳', label: 'Reset zoom', handler: handlers.reset, attr: 'data-mermaid-zoom="reset"' }
  ])

  const panGroup = createButtonGroup('Pan controls', [
    { text: '↑', label: 'Pan up', handler: () => handlers.panBy(0, -80), attr: 'data-mermaid-pan="up"' },
    { text: '←', label: 'Pan left', handler: () => handlers.panBy(-80, 0), attr: 'data-mermaid-pan="left"' },
    { text: '→', label: 'Pan right', handler: () => handlers.panBy(80, 0), attr: 'data-mermaid-pan="right"' },
    { text: '↓', label: 'Pan down', handler: () => handlers.panBy(0, 80), attr: 'data-mermaid-pan="down"' }
  ])

  const downloadGroup = document.createElement('div')
  downloadGroup.className = 'btn-group btn-group-sm'
  downloadGroup.role = 'group'
  downloadGroup.setAttribute('aria-label', 'Download controls')
  downloadGroup.innerHTML = `
    <button type="button" class="btn btn-outline-secondary btn-sm px-2 py-1 dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false" aria-label="Download diagram">
      <i class="fas fa-download" aria-hidden="true"></i>
    </button>
    <ul class="dropdown-menu">
      <li><button type="button" class="dropdown-item" data-mermaid-download="mmd">Download .mmd</button></li>
      <li><button type="button" class="dropdown-item" data-mermaid-download="png">Download .png</button></li>
      <li><button type="button" class="dropdown-item" data-mermaid-download="jpg">Download .jpg</button></li>
    </ul>
  `
  downloadGroup.querySelector('[data-mermaid-download="mmd"]').addEventListener('click', (e) => { e.preventDefault(); handlers.downloadMmd() })
  downloadGroup.querySelector('[data-mermaid-download="png"]').addEventListener('click', (e) => { e.preventDefault(); handlers.downloadPng() })
  downloadGroup.querySelector('[data-mermaid-download="jpg"]').addEventListener('click', (e) => { e.preventDefault(); handlers.downloadJpg() })

  fullscreenControls.appendChild(fullscreenGroup)
  fullscreenControls.appendChild(zoomGroup)
  fullscreenControls.appendChild(panGroup)
  fullscreenControls.appendChild(downloadGroup)

  overlay.appendChild(closeButton)
  overlay.appendChild(fullscreenViewport)
  overlay.appendChild(fullscreenControls)

  // Re-attach drag pan to fullscreen viewport
  attachDragPan(fullscreenViewport)

  return overlay
}

function createButtonGroup(label, buttons) {
  const group = document.createElement('div')
  group.className = 'btn-group btn-group-sm'
  group.role = 'group'
  group.setAttribute('aria-label', label)

  buttons.forEach(({ text, icon, label, handler, attr }) => {
    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'btn btn-outline-secondary btn-sm px-2 py-1'
    button.setAttribute('aria-label', label)
    if (attr) {
      const [key, value] = attr.includes('=') ? attr.split('=').map(s => s.replace(/"/g, '')) : [attr, '']
      button.setAttribute(key, value)
    }
    if (icon) {
      button.innerHTML = `<i class="fas ${icon}" aria-hidden="true"></i>`
    } else {
      button.textContent = text
    }
    button.addEventListener('click', handler)
    group.appendChild(button)
  })

  return group
}
