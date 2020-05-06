#
# Runs Passport.js setup code including mounting strategies, serializers, etc.
#

passport = require 'passport'
FacebookStrategy = require('passport-facebook').Strategy
AppleStrategy = require('@nicokaiser/passport-apple').Strategy
LocalWithOtpStrategy = require('@artsy/passport-local-with-otp').Strategy
callbacks = require './callbacks'
{ serialize, deserialize } = require './serializers'
opts = require '../options'

module.exports = ->
  passport.serializeUser serialize
  passport.deserializeUser deserialize
  passport.use new LocalWithOtpStrategy(
    {
      usernameField: 'email'
      otpField: 'otp_attempt'
      passReqToCallback: true
    },
    callbacks.local
    )
  if opts.FACEBOOK_ID and opts.FACEBOOK_SECRET
    passport.use new FacebookStrategy(
      {
        state: true
        clientID: opts.FACEBOOK_ID
        clientSecret: opts.FACEBOOK_SECRET
        passReqToCallback: true
        callbackURL: "#{opts.APP_URL}#{opts.facebookCallbackPath}"
      },
      callbacks.facebook
    )

  if opts.APPLE_CLIENT_ID and opts.APPLE_TEAM_ID and
     opts.APPLE_KEY_ID and opts.APPLE_PRIVATE_KEY
    passport.use 'apple', new AppleStrategy(
      {
        clientID: opts.APPLE_CLIENT_ID
        teamID: opts.APPLE_TEAM_ID
        keyID: opts.APPLE_KEY_ID
        key: opts.APPLE_PRIVATE_KEY
        passReqToCallback: true
        callbackURL: "#{opts.APP_URL}#{opts.appleCallbackPath}"
        scope: ['name', 'email']
      },
      callbacks.apple
    )
