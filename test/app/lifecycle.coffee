sinon = require 'sinon'
rewire = require 'rewire'
lifecycle = rewire '../../lib/app/lifecycle'

describe 'lifecycle', ->

  beforeEach ->
    @req = { body: {}, params: {}, query: {}, session: {}, get: sinon.stub() }
    @res = { redirect: sinon.stub(), send: sinon.stub() }
    @next = sinon.stub()
    @passport = {}
    @passport.authenticate = sinon.stub()
    @passport.authenticate.returns (req, res, next) -> next()
    @request = sinon.stub().returns @request
    for method in ['get', 'end', 'set', 'post', 'send']
      @request[method] = sinon.stub().returns @request
    lifecycle.__set__ 'request', @request
    lifecycle.__set__ 'passport', @passport
    lifecycle.__set__ 'opts', @opts = {
      loginPagePath: '/login'
      afterSignupPagePath: '/personalize'
      APP_URL: 'https://www.artsy.net'
      ARTSY_URL: 'https://api.artsy.net'
    }

  describe '#onLocalLogin', ->

    context 'when successful', ->

      beforeEach ->
        @passport.authenticate.returns (req, res, next) -> next()

      it 'authenticates locally and passes on', ->
        @opts.APP_URL = 'localhost'
        lifecycle.onLocalLogin @req, @res, @next
        @passport.authenticate.args[0][0].should.equal 'local'
        @next.called.should.be.ok()

      it 'authenticates locally and passes on', ->
        @opts.APP_URL = 'localhost'
        @req.query['redirect-to'] = '/foobar'
        lifecycle.onLocalLogin @req, @res, @next
        @next.called.should.be.ok()

    context 'when erroring', ->

      beforeEach ->
        @passport.authenticate.returns (req, res, next) => next @err

      it 'redirects invalid passwords to login', ->
        @err = { response: { body: { error_description: 'invalid email or password' } } }
        lifecycle.onLocalLogin @req, @res, @next
        @res.redirect.args[0][0]
          .should.equal '/login?error=Invalid email or password.'

      it 'sends generic error to the error handler', ->
        @err = new Error 'moo'
        lifecycle.onLocalLogin @req, @res, @next
        @next.args[0][0].message.should.equal 'moo'

  describe '#onError', ->

    xit 'Nexts on error', ->
      lifecycle.onError new Error('twitter denied'), @req, @res, @next
      @res.redirect.args[0][0].should.equal '/login?error=Canceled Twitter login'

  describe '#onLocalSignup', ->

    it 'creatse a user'

    it 'suggests an email if its invalid and redirects back to the signup page'

    it 'sends 500s as json for xhr requests'

    it 'passes the recaptcha_token through signup', ->
      @req.body.recaptcha_token = 'recaptcha_token'
      lifecycle.onLocalSignup @req, @res, @next
      @request.send.args[0][0].recaptcha_token.should.equal 'recaptcha_token'

    it 'passes the user agent through signup', ->
      @req.get.returns 'foo-agent'
      lifecycle.onLocalSignup @req, @res, @next
      @request.set.args[0][0]['User-Agent'].should.equal 'foo-agent'

  describe '#beforeSocialAuth', ->
    it 'sets session redirect', ->
      @req.query['redirect-to'] = '/foobar'
      @passport.authenticate.returns (req, res, next) -> next()
      lifecycle.beforeSocialAuth('facebook')(@req, @res, @next)
      @req.session.redirectTo.should.equal '/foobar'
      @passport.authenticate.args[0][1].scope.should.equal 'email'

    it 'sets the session to skip onboarding', ->
      @passport.authenticate.returns (req, res, next) -> next()
      @req.query['skip-onboarding'] = true
      lifecycle.beforeSocialAuth('facebook')(@req, @res, @next)
      @req.session.skipOnboarding.should.equal(true)

    it 'asks for linked in profile info'

    it 'asks for email scope if not linkedin'

  describe '#afterSocialAuth', ->
    it 'doesnt redirect to personalize if skip-onboarding is set', ->
      @req.artsyPassportSignedUp = true
      @req.session.skipOnboarding = true
      @passport.authenticate.returns (req, res, next) -> next()
      lifecycle.afterSocialAuth('facebook')(@req, @res, @next)
      @res.redirect.called.should.not.be.ok()

    it 'surfaces blocked by facebook errors', ->
      @passport.authenticate.returns (req, res, next) ->
        next new Error 'Unauthorized source IP address'
      lifecycle.afterSocialAuth('facebook')(@req, @res, @next)
      @res.redirect.args[0][0]
        .should.equal '/login?error=Your IP address was blocked by Facebook.'

    it 'passes random errors to be rendered on the login screen', ->
      @passport.authenticate.returns (req, res, next) ->
        next new Error 'Facebook authorization failed'
      lifecycle.afterSocialAuth('facebook')(@req, @res, @next)
      @res.redirect.args[0][0]
        .should.equal '/login?error=Facebook authorization failed'

    context 'with an error', ->

      it 'redirects back to the login page and explains the account ' +
         'was previously linked'

      it 'redirects to the settings page and explains if the account is linked ' +
         'to another account'

      it 'passes unknown errors'

    context 'when successful', ->

      it 'redirects to settings if linking'

      it 'redirects to the personalize page if signing up'

      it 'reidrects back if logging in'

  describe '#ensureLoggedInOnAfterSignupPage', ->

    it 'redirects to the login page, and back, without a user', ->
      lifecycle.ensureLoggedInOnAfterSignupPage @req, @res, @next
      @res.redirect.args[0][0].should.equal '/login?redirect-to=/personalize'

  describe '#ssoAndRedirectBack', ->

    it 'redirects signups to personalize', ->
      @req.user = { get: -> 'token' }
      @req.artsyPassportSignedUp = true
      lifecycle.ssoAndRedirectBack @req, @res, @next
      @request.end.args[0][0] null, { body: { trust_token: 'foo-trust-token' } }
      @res.redirect.args[0][0].should.containEql '/personalize'

    it 'doesnt redirect to personalize if skipping onboarding', ->
      @req.artsyPassportSignedUp = true
      @req.session.skipOnboarding = true
      @req.user = { get: -> 'token' }
      @req.artsyPassportSignedUp = true
      lifecycle.ssoAndRedirectBack @req, @res, @next
      @request.end.args[0][0] null, { body: { trust_token: 'foo-trust-token' } }
      @res.redirect.args[0][0].should.not.containEql '/personalize'

    it 'passes on for xhrs', ->
      @req.xhr = true
      @req.user = { toJSON: -> }
      lifecycle.ssoAndRedirectBack @req, @res, @next
      @res.send.args[0][0].success.should.equal true

    it 'single signs on to gravity', ->
      @req.user = { get: -> 'token' }
      @req.query['redirect-to'] = '/artwork/andy-warhol-skull'
      lifecycle.ssoAndRedirectBack @req, @res, @next
      @request.post.args[0][0].should.containEql 'me/trust_token'
      @request.end.args[0][0] null, { body: { trust_token: 'foo-trust-token' } }
      @res.redirect.args[0][0].should.equal(
        'https://api.artsy.net/users/sign_in' +
        '?trust_token=foo-trust-token' +
        '&redirect_uri=https://www.artsy.net/artwork/andy-warhol-skull'
      )

