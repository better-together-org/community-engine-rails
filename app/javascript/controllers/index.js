// require better_together/controllers/application

import { application } from 'controllers/better_together/application'
import { createDebug } from 'better_together/debugger'

// load all controllers defined in the import map under controllers/**/*_controller
import { lazyLoadControllersFrom } from 'stimulus-loading'
lazyLoadControllersFrom('controllers/better_together', application)

const debug = createDebug(application)
debug.log('[Stimulus] Controllers index loaded')
