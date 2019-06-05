#
# Runs Passport.js setup code including mounting strategies, serializers, etc.
#

passport = require 'passport'
FacebookStrategy = require('passport-facebook').Strategy
LocalStrategy = require('passport-local').Strategy
callbacks = require './callbacks'
{ serialize, deserialize } = require './serializers'
opts = require '../options'

module.exports = ->
  passport.serializeUser serialize
  passport.deserializeUser deserialize
  passport.use new LocalStrategy(
    {
      usernameField: 'email'
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
