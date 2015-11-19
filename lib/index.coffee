#
# Uses [passport.js](http://passportjs.org/) to setup authentication with
# various providers like direct login with Artsy, or oauth signin with Facebook
# or Twitter.
#

_ = require 'underscore'
opts = require './options'
setupApp = require './app'
setupPassport = require './passport'

module.exports = (options) =>
  _.extend opts, options
  setupPassport()
  setupApp()

module.exports.options = opts
