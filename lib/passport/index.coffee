#
# Runs Passport.js setup code including mounting strategies, serializers, etc.
#

passport = require 'passport'
FacebookStrategy = require('passport-facebook').Strategy
TwitterStrategy = require('passport-twitter').Strategy
LocalStrategy = require('passport-local').Strategy
LinkedInStrategy = require('passport-linkedin').Strategy
callbacks = require './callbacks'
{ serialize, deserialize } = require './serializers'
opts = require '../options'

module.exports = ->
  passport.serializeUser serialize
  passport.deserializeUser deserialize
  passport.use new LocalStrategy
    usernameField: 'email'
    passReqToCallback: true
  , callbacks.local
  if opts.FACEBOOK_ID and opts.FACEBOOK_SECRET
    passport.use new FacebookStrategy
      state: true
      clientID: opts.FACEBOOK_ID
      clientSecret: opts.FACEBOOK_SECRET
      passReqToCallback: true
      callbackURL: "#{opts.APP_URL}#{opts.facebookCallbackPath}"
    , callbacks.facebook
  if opts.TWITTER_KEY and opts.TWITTER_SECRET
    passport.use new TwitterStrategy
      consumerKey: opts.TWITTER_KEY
      consumerSecret: opts.TWITTER_SECRET
      passReqToCallback: true
      callbackURL: "#{opts.APP_URL}#{opts.twitterCallbackPath}"
    , callbacks.twitter
  if opts.LINKEDIN_KEY and opts.LINKEDIN_SECRET
    passport.use new LinkedInStrategy
      consumerKey: opts.LINKEDIN_KEY
      consumerSecret: opts.LINKEDIN_SECRET
      passReqToCallback: true
      callbackURL: "#{opts.APP_URL}#{opts.linkedinCallbackPath}"
      profileFields: [
        'id', 'first-name', 'last-name', 'email-address', 'headline', 'location',
        'industry', 'summary', 'specialties', 'positions', 'public-profile-url'
      ]
    , callbacks.linkedin

