// require better_together/controllers/application

import { application } from './controllers/application'

// load all controllers defined in the import map under controllers/**/*_controller
import { lazyLoadControllersFrom } from 'stimulus-loading'
lazyLoadControllersFrom('./better_together/controllers', application)

console.log('controllers index')
