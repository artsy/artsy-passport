#
# Twitter last step logic. Used to ensure we have an email from users that
# sign up with Twitter.
#

_ = require 'underscore'
passport = require 'passport'
request = require 'superagent'
opts = require '../options'

@ensureEmail = (req, res, next) ->
  return next() unless req.user?
  tmpSuffix = _.last(opts.twitterSignupTempEmail('').split('@'))
  if req.user.get('email').match tmpSuffix
    res.redirect opts.twitterLastStepPath
  else
    next()

@login = (req, res, next) ->
  return next() if req.user
  passport.authenticate('twitter',
    callbackURL: "#{opts.APP_URL}#{opts.twitterLastStepPath}"
  )(req, res, next)