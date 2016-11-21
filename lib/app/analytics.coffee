opts = require '../options'
Analytics = require 'analytics-node'

@setCampaign = (req, res, next) ->
  return next() unless opts.SEGMENT_WRITE_KEY
  req.session.modalId = req.params.modal_id
  req.session.acquisitionInitiative = req.params.acquisition_initiative
  next()

@trackSignup = (service) -> (req, res, next) ->
  return next() unless opts.SEGMENT_WRITE_KEY
  analytics = new Analytics opts.SEGMENT_WRITE_KEY
  analytics.track
    event: 'Created account'
    userId: req.user.get 'id'
    properties:
      modal_id: req.session.modalId
      acquisition_initiative: req.session.acquisitionInitiative
      signup_service: service
      user_id: req.user.get 'id'
  req.session.modalId = null
  req.session.acquisitionInitiative = null
  next()
