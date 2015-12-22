#
# Uses [passport.js](http://passportjs.org/) to setup authentication with
# various providers like direct login with Artsy, or oauth signin with Facebook
# or Twitter.
#

_ = require 'underscore'
opts = require './options'
setupApp = require './app'
setupPassport = require './passport'
artsyXapp = require 'artsy-xapp'

module.exports = (options) =>
  _.extend opts, _.pick options, 'FACEBOOK_ID','FACEBOOK_SECRET',
    'TWITTER_KEY','TWITTER_SECRET','TWITTER_KEY','TWITTER_SECRET',
    'LINKEDIN_KEY','LINKEDIN_SECRET','ARTSY_ID','ARTSY_SECRET','ARTSY_URL',
    'APP_URL','linkedinPath','linkedinCallbackPath','facebookPath',
    'facebookCallbackPath','twitterPath','twitterCallbackPath',
    'twitterLastStepPath','twitterSignupTempEmail','loginPagePath',
    'signupPagePath','settingsPagePath','afterSignupPagePath','logoutPath',
    'userKeys', 'CurrentUser'
  setupPassport()
  setupApp()

module.exports.options = opts
