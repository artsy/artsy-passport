#
# Twitter last step logic. Used to ensure we have an email from users that
# sign up with Twitter.
#

_ = require 'underscore'
passport = require 'passport'
request = require 'superagent'
opts = require '../options.coffee'

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

@submit = (req, res, next) ->
  return next new Error "No user" unless req.user
  return next new Error "No email provided" unless req.body.email?
  request.put("#{opts.ARTSY_URL}/api/v1/me").send(
    email: req.body.email
    email_confirmation: req.body.email
    access_token: req.user.get('accessToken')
  ).end (err, r) ->
    return next err if err
    # To work around an API caching bug we send another empty PUT and
    # update the current user.
    request.put("#{opts.ARTSY_URL}/api/v1/me").send(
      access_token: req.user.get('accessToken')
    ).end (err, r) ->
      return next err if err
      req.login req.user.set(r.body), (err) ->
        return next err if err
        res.redirect opts.afterSignupPagePath

@error = (err, req, res, next) ->
  return next() if err.text?.match 'Error from MailChimp API'
  msg = err.response.body?.error or err.message or err.toString()
  if msg is 'User Already Exists'
    href = "#{opts.logoutPath}?redirect-to=#{opts.loginPagePath}"
    msg = "An account with this email address already exists. If this is " +
          "your account please " +
          "log in to Artsy with your email and password, and link your Twitter account" +
          "in your settings instead."
  res.redirect opts.twitterLastStepPath + '?error=' + msg
