sinon = require 'sinon'
rewire = require 'rewire'
lifecycle = rewire '../../lib/app/lifecycle'

describe 'lifecycle', ->

  beforeEach ->
    @req = { body: {}, params: {}, query: {}, session: {} }
    @res = { redirect: sinon.stub(), send: sinon.stub() }
    @next = sinon.stub()
    @passport = {}
    @passport.authenticate = sinon.stub()
    lifecycle.__set__ 'passport', @passport
    lifecycle.__set__ 'opts',
      loginPagePath: '/login'
      afterSignupPagePath: '/signup'

  describe '#onLocalLogin', ->

    context 'when successful', ->

      beforeEach ->
        @passport.authenticate.returns (req, res, next) -> next()

      it 'authenticates locally and redirects home', ->
        lifecycle.onLocalLogin @req, @res, @next
        @passport.authenticate.args[0][0].should.equal 'local'
        @res.redirect.args[0][0].should.equal '/'

      it 'authenticates locally and redirects back', ->
        @req.query['redirect-to'] = '/foobar'
        lifecycle.onLocalLogin @req, @res, @next
        @res.redirect.args[0][0].should.equal '/foobar'

      it 'sends json for xhrs', ->
        @req.xhr = true
        @req.user = { toJSON: -> }
        lifecycle.onLocalLogin @req, @res, @next
        @res.send.args[0][0].success.should.equal true

      it 'redirects signups to personalize', ->
        @req.artsyPassportSignedUp = true
        lifecycle.onLocalLogin @req, @res, @next
        @res.redirect.args[0][0].should.equal '/signup'

    context 'when erroring', ->

      beforeEach ->
        @passport.authenticate.returns (req, res, next) => next @err

      it 'redirects invalid passwords to login', ->
        @err = response: body: error_description: 'invalid email or password'
        lifecycle.onLocalLogin @req, @res, @next
        @res.redirect.args[0][0]
          .should.equal '/login?error=Invalid email or password.'

      it 'sends generic error to the error handler', ->
        @err = new Error 'moo'
        lifecycle.onLocalLogin @req, @res, @next
        @next.args[0][0].message.should.equal 'moo'

  describe '#onError', ->

    it 'handles canceled twitter logins', ->
      lifecycle.onError new Error('twitter denied'), @req, @res, @next
      @res.redirect.args[0][0].should.equal '/login?error=Canceled Twitter login'

  describe '#onLocalSignup', ->

    it 'creatse a user'

    it 'suggests an email if its invalid and redirects back to the signup page'

    it 'sends 500s as json for xhr requests'

  describe '#beforeSocialAuth', ->

    it 'creates a state param for twitter', ->
      @passport.authenticate.returns (req, res, next) -> next()
      lifecycle.beforeSocialAuth('twitter')(@req, @res, @next)
      @req.session.twitterState.length.should.be.above 5
      @passport.authenticate.args[0][1].callbackURL
        .should.containEql "state=#{@req.session.twitterState}"

    it 'can skip onboarding', ->
      @passport.authenticate.returns (req, res, next) -> next()
      @req.query['skip-onboarding'] = true
      lifecycle.beforeSocialAuth('facebook')(@req, @res, @next)
      console.log @req.session, 'moo'
      @req.session.skipOnboarding.should.equal('true')
      console.log @res.redirect.args

    it 'asks for linked in profile info'

    it 'asks for email scope if not linkedin'

  describe '#afterSocialAuth', ->

    it 'ensures a state param for twitter', ->
      @req.query.state = 'foo'
      @req.session.twitterState = 'bar'
      @passport.authenticate.returns (req, res, next) -> next()
      lifecycle.afterSocialAuth('twitter')(@req, @res, @next)
      @next.args[0][0].message.should.equal 'Must pass a valid `state` param.'

    context 'with an error', ->

      it 'redirects back to the login page and explains the account ' +
         'was previously linked'

      it 'redirects to the settings page and explains if the account is linked ' +
         'to another account'

      it 'passes unknown errors'

    context 'when successful', ->

      it 'redirects to settings if linking'

      it 'redirects to the twitter last step if signing up with twitter'

      it 'redirects to the personalize page if signing up without twitter'

      it 'reidrects back if logging in'

  describe '#ensureLoggedInOnAfterSignupPage', ->

    it 'redirects to the login page without a user'
