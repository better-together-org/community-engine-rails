// Leaflet plugins (leaflet.markercluster) assign their classes onto the global L. Depending on how Leaflet was
// loaded that global can be a sealed module namespace, so give plugins a plain extensible copy first (the classes
// and functions are shared with the original, not cloned).
import * as namespace from 'leaflet'

const base = window.L || namespace
if (!Object.isExtensible(base)) window.L = Object.assign({}, base)
