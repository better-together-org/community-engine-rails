// Debug wrapper that only logs when Stimulus debug mode is enabled
// 
// Usage Option 1: Extend ApplicationController (automatic debug support)
// ----------------------------------------------------------------
// import { ApplicationController } from "controllers/better_together/application"
// 
// export default class extends ApplicationController {
//   connect() {
//     super.connect() // This initializes this.debug
//     this.debug.log('Controller connected')
//   }
// }
//
// Usage Option 2: Manual initialization
// -------------------------------------
// import { Controller } from "@hotwired/stimulus"
// import { createDebug } from "better_together/debugger"
// 
// export default class extends Controller {
//   connect() {
//     this.debug = createDebug('MyController', this.application)
//     this.debug.log('Controller connected')
//   }
// }
//
// Available methods:
// - this.debug.log(...args)       - Standard console.log
// - this.debug.warn(...args)      - Console warning
// - this.debug.error(...args)     - Console error
// - this.debug.table(data)        - Console table
// - this.debug.group(label, fn)   - Grouped console output
// - this.debug.time(label, fn)    - Time function execution

export class Debug {
  constructor(controllerName, application) {
    this.controllerName = controllerName
    this.application = application
  }

  // Check if debug mode is enabled
  get enabled() {
    return this.application?.debug === true
  }

  // Log a message (only if debug enabled)
  log(...args) {
    if (this.enabled) {
      console.log(`[${this.controllerName}]`, ...args)
    }
  }

  // Log a warning (only if debug enabled)
  warn(...args) {
    if (this.enabled) {
      console.warn(`[${this.controllerName}]`, ...args)
    }
  }

  // Log an error (only if debug enabled)
  error(...args) {
    if (this.enabled) {
      console.error(`[${this.controllerName}]`, ...args)
    }
  }

  // Log grouped content (only if debug enabled)
  group(label, callback) {
    if (this.enabled) {
      console.group(`[${this.controllerName}] ${label}`)
      callback()
      console.groupEnd()
    }
  }

  // Log a table (only if debug enabled)
  table(data) {
    if (this.enabled) {
      console.log(`[${this.controllerName}]`)
      console.table(data)
    }
  }

  // Time a function execution (only if debug enabled)
  time(label, callback) {
    if (this.enabled) {
      const timerLabel = `[${this.controllerName}] ${label}`
      console.time(timerLabel)
      const result = callback()
      console.timeEnd(timerLabel)
      return result
    }
    return callback()
  }
}

// Export a helper function to create a debug instance
export function createDebug(controllerName, application) {
  return new Debug(controllerName, application)
}
