opts = require '../options'
Analytics = require 'analytics-node'

@setCampaign = (req, res, next) ->
  return next() unless opts.SEGMENT_WRITE_KEY
  req.session.modalId = (
    req.body.modal_id or
    req.query.modal_id
  )
  req.session.acquisitionInitiative = (
    req.body.acquisition_initiative or
    req.query.acquisition_initiative
  )
  next()

@trackSignup = (service) -> (req, res, next) ->
  modalId = req.session.modalId
  acquisitionInitiative = req.session.acquisitionInitiative
  delete req.session.acquisitionInitiative
  delete req.session.modalId
  return next() unless opts.SEGMENT_WRITE_KEY
  analytics = new Analytics opts.SEGMENT_WRITE_KEY
  analytics.track
    event: 'Created account'
    userId: req.user.get 'id'
    properties:
      modal_id: modalId
      acquisition_initiative: acquisitionInitiative
      signup_service: service
      user_id: req.user.get 'id'
  next()

@trackLogin = (req, res, next) ->
  return next() unless opts.SEGMENT_WRITE_KEY
  analytics = new Analytics opts.SEGMENT_WRITE_KEY
  analytics.track
    event: 'Successfully logged in'
    userId: req.user.get 'id'
  next()
