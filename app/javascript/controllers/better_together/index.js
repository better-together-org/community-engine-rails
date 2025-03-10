// require better_together/controllers/application

import { application } from 'better_together/controllers/application'

// load all controllers defined in the import map under controllers/**/*_controller
import { lazyLoadControllersFrom } from 'stimulus-loading'
lazyLoadControllersFrom('controllers/better_together', application)

console.log('controllers index')
