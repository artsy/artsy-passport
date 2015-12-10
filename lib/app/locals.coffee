opts = require '../options'

module.exports = (req, res, next) ->
  if req.user
    res.locals.user = req.user
    res.locals.sd?.CURRENT_USER = req.user.toJSON()
  res.locals.sd?.CSRF_TOKEN = res.locals.csrfToken = req.csrfToken?()
  res.locals.sd?.ERROR = res.locals.error = req.query.error
  res.locals.sd?.AP = res.locals.ap = opts
  next()