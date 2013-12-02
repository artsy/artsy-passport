express = require 'express'
artsyPassport = require '../'
Backbone = require 'backbone'
sharify = require 'sharify'
fs = require 'fs'
config = require './config.coffee'

class CurrentUser extends Backbone.Model
  beep: -> 'boop'

app = module.exports = express()
app.set 'views', __dirname
app.set 'view engine', 'jade'
app.get '/', (req, res) -> res.render 'login'

app.use artsyAuth _.extend config,
  currentUserModel: CurrentUser
  sharifyData: sharify.data

app.listen 4000, -> console.log "Example listening on 4000"