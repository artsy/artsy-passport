opts = require '../options'

module.exports = (req, res, next) ->
  if req.user
    res.locals.user = req.user
    res.locals.sd?.CURRENT_USER = req.user.toJSON()
  res.locals.sd?.APOPTS = res.locals.apopts = opts
  res.locals.sd?.CSRF_TOKEN = res.locals.csrfToken = req.csrfToken?()
  next()