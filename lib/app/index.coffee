#
# Sets up the express application to be mounted. Includes mounting
# Artsy flow related callbacks like sending people to /personalize after signup,
# ensuring the Twitter "one last step" appears if someone signs up with Twitter
# and doesn't provide their email, throwing edge case errors that our API
# returns, and more.
#

express = require 'express'
csrf = require 'csurf'
passport = require 'passport'
app = express()
opts = require '../options'
twitterLastStep = require './twitter_last_step'
{ onLocalLogin, onLocalSignup, beforeSocialAuth,
  afterSocialAuth, ensureLoggedInOnAfterSignupPage, onError } = require './lifecycle'
{ denyBadLogoutLinks, logout } = require './logout'
{ headerLogin, trustTokenLogin } = require './token_login'
addLocals = require './locals'

module.exports = ->

  # Mount passport and ensure CSRF protection across GET requests
  app.use passport.initialize(), passport.session()
  app.get '*', csrf(cookie: true)

  # Local email/password auth
  app.post opts.loginPagePath, csrf(cookie: true), onLocalLogin
  app.post opts.signupPagePath, onLocalSignup, onLocalLogin

  # Twitter/Facebook OAuth
  app.get opts.twitterPath, beforeSocialAuth('twitter')
  app.get opts.facebookPath, beforeSocialAuth('facebook')
  app.get opts.linkedinPath, beforeSocialAuth('linkedin')
  app.get opts.twitterCallbackPath, afterSocialAuth('twitter')
  app.get opts.facebookCallbackPath, afterSocialAuth('facebook')
  app.get opts.linkedinCallbackPath, afterSocialAuth('linkedin')

  # Twitter "one last step" UI
  app.get '/', twitterLastStep.ensureEmail
  app.get opts.twitterLastStepPath, twitterLastStep.login
  app.post opts.twitterLastStepPath, csrf(cookie: true), twitterLastStep.submit, twitterLastStep.error

  # Logout middleware
  app.get opts.logoutPath, denyBadLogoutLinks, logout
  app.delete opts.logoutPath, logout

  # Ensure the user is logged in before personalize
  app.get opts.afterSignupPagePath, ensureLoggedInOnAfterSignupPage

  # Convenience middleware for token login and locals like sd.CURRENT_USER
  app.use headerLogin, trustTokenLogin, addLocals, onError

  # Return the app
  app
