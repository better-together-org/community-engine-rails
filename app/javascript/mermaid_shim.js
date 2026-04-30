// ESM shim — wraps the Mermaid UMD bundle so importmap consumers get a stable
// module path without the package's internal relative chunk imports.
import 'mermaid_umd'

const mermaid = () => globalThis.mermaid ?? {}

export const initialize = (...args) => mermaid().initialize?.(...args)
export const init = (...args) => mermaid().init?.(...args)
export const run = (...args) => mermaid().run?.(...args)
export const parse = (...args) => mermaid().parse?.(...args)
export const render = (...args) => mermaid().render?.(...args)
export const contentLoaded = (...args) => mermaid().contentLoaded?.(...args)

export default mermaid()
