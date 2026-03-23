// app/javascript/controllers/index.js

// import { application } from 'controllers/application'
import { createDebug } from 'better_together/debugger'

// Load all host's controllers defined in the import map under controllers/**/*_controller
import { lazyLoadControllersFrom } from 'stimulus-loading'
lazyLoadControllersFrom('controllers', application)

const debug = createDebug(application)
debug.log('[Stimulus] Dummy app controllers index loaded')
