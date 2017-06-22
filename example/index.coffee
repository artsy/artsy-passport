_ = require 'underscore'
fs = require 'fs'
express = require 'express'
Backbone = require 'backbone'
sharify = require 'sharify'
backboneSuperSync = require 'backbone-super-sync'
bodyParser = require 'body-parser'
cookieParser = require 'cookie-parser'
session = require 'cookie-session'
path = require "path"
logger = require 'morgan'
artsyXapp = require 'artsy-xapp'
artsyPassport = require '../'
config = require '../config'

# CurrentUser class
class CurrentUser extends Backbone.Model
  url: -> "#{config.ARTSY_URL}/api/v1/me"
  sync: (method, model, options = {}) ->
    options.headers ?= {}
    options.headers['X-Access-Token'] = @get 'accessToken'
    super
  unlink: (options) ->
    auth = new Backbone.Model id: 'foo'
    auth.url = "#{config.ARTSY_URL}/api/v1/me/authentications/#{options.provider}"
    auth.destroy
      headers: 'X-Access-Token': @get 'accessToken'
      error: options.error
      success: => @fetch options

sharify.data = config

setup = (app) ->

  app.use sharify

  Backbone.sync = backboneSuperSync

  app.set 'views', __dirname
  app.set 'view engine', 'jade'

  app.use bodyParser.json()
  app.use bodyParser.urlencoded(extended: true)
  app.use cookieParser()
  app.use session
    secret: 'super-secret'
    key: 'artsy-passport'
  app.use logger('dev')

  app.use express.static __dirname + '/public'

  # Setup Artsy Passport
  app.use artsyPassport _.extend config,
    CurrentUser: CurrentUser
  { loginPagePath, signupPagePath, settingsPagePath,
    afterSignupPagePath, twitterLastStepPath, logoutPath } = artsyPassport.options

  # App specific routes that render a login/signup form and logged in view
  app.get '(/|/log_in|/sign_up|/user/edit)', (req, res) ->
    if req.user? then res.render 'loggedin' else res.render 'login'
  app.get afterSignupPagePath, (req, res) ->
    res.render 'personalize'
  app.get twitterLastStepPath, (req, res) ->
    res.render 'onelaststep'

  # Potential candidates to be first class in AP. Delete, unlink account,
  # and reset password handlers
  app.get '/deleteaccount', (req, res, next) ->
    return next() unless req.user?
    req.user.destroy
      error: (m, e) -> next e
      success: -> res.redirect logoutPath
  app.get '/unlink/:provider', (req, res, next) ->
    req.user.unlink
      provider: req.params.provider
      error: (m, e) -> next e
      success: (user, r) ->
        req.login user, (err) ->
          return next err if err
          res.redirect settingsPagePath
  app.post '/reset', (req, res, next) ->
    reset = new Backbone.Model
    reset.url = "#{config.ARTSY_URL}/api/v1/users/send_reset_password_instructions"
    reset.save { email: req.body.email },
      headers: 'X-Xapp-Token': artsyXapp.token
      error: (m, e) -> next e
      success: (m, r) -> res.redirect '/newpassword'
  app.get '/newpassword', (req, res, next) ->
    res.render 'newpassword'
  app.post '/newpassword', (req, res, next) ->
    reset = new Backbone.Model id: 'foo'
    reset.url = "#{config.ARTSY_URL}/api/v1/users/reset_password"
    reset.save req.body,
      headers: 'X-Xapp-Token': artsyXapp.token
      error: (m, e) -> next e
      success: (m, r) -> res.redirect loginPagePath
  app.get '/nocsrf', (req, res) ->
    res.render 'nocsrf'

  # Error handler
  app.use (err, req, res, next) ->
    console.warn err.stack
    res.render 'error', err: err?.response?.body?.error or err.stack

  # Start server
  return unless module is require.main
  artsyXapp.on('error', (e) -> console.warn(e); process.exit(1)).init
    url: config.ARTSY_URL
    id: config.ARTSY_ID
    secret: config.ARTSY_SECRET
  , ->
    app.listen 4000, -> console.log "Example listening on #{4000}"

app = module.exports = express()
setup app
