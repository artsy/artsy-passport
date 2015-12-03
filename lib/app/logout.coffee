#
# Logout helpers.
#

request = require 'superagent'
opts = require '../options'
{ parse } = require 'url'
redirectBack = require './redirectback'

@denyBadLogoutLinks = (req, res, next) ->
  if parse(req.get 'Referrer').hostname.match 'artsy.net'
    next()
  else
    next new Error "Malicious logout link."

@logout = (req, res, next) ->
  accessToken = req.user?.get('accessToken')
  req.logout()
  request
    .del("#{opts.ARTSY_URL}/api/v1/access_token")
    .send(access_token: accessToken)
    .end (error, response) ->
      if req.xhr
        res.status(200).send msg: 'success'
      else
        redirectBack req, res
