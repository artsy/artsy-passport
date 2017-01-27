Backbone = require 'backbone'
rewire = require 'rewire'
sinon = require 'sinon'
cbs = rewire '../../lib/passport/callbacks'

describe 'passport callbacks', ->

  beforeEach ->
    @req = get: sinon.stub()
    @request = {}
    @request.get = sinon.stub().returns @request
    @request.query = sinon.stub().returns @request
    @request.set = sinon.stub().returns @request
    @request.end = sinon.stub().returns @request
    @request.post = sinon.stub().returns @request
    @request.send = sinon.stub().returns @request
    cbs.__set__ 'request', @request
    cbs.__set__ 'opts',
      ARTSY_ID: 'artsy-id'
      ARTSY_SECRET: 'artsy-secret'
      ARTSY_URL: 'http://apiz.artsy.net'
      CurrentUser: Backbone.Model
      twitterSignupTempEmail: (str) -> str + '@artsy.tmp'

  it 'get a user with an access token email/password', (done) ->
    cbs.local @req, 'craig', 'foo', (err, user) ->
      user.get('accessToken').should.equal 'access-token'
      done()
    @request.post.args[0][0].should
      .equal 'http://apiz.artsy.net/oauth2/access_token'
    res = { body: { access_token: 'access-token' }, status: 200 }
    @request.end.args[0][0](null, res)

  it 'get a user with an access token facebook', (done) ->
    cbs.facebook @req, 'foo-token', 'refresh-token', {}, (err, user) ->
      user.get('accessToken').should.equal 'access-token'
      done()
    @request.post.args[0][0].should
      .equal 'http://apiz.artsy.net/oauth2/access_token'
    queryParams = @request.query.args[0][0]
    queryParams.oauth_provider.should.equal 'facebook'
    queryParams.oauth_token.should.equal 'foo-token'
    res = { body: { access_token: 'access-token' }, status: 200 }
    @request.end.args[0][0](null, res)

  it 'get a user with an access token via twitter', (done) ->
    cbs.twitter @req, 'foo-token', 'token-secret', {}, (err, user) ->
      user.get('accessToken').should.equal 'access-token'
      done()
    @request.post.args[0][0].should
      .equal 'http://apiz.artsy.net/oauth2/access_token'
    queryParams = @request.query.args[0][0]
    queryParams.oauth_provider.should.equal 'twitter'
    queryParams.oauth_token.should.equal 'foo-token'
    queryParams.oauth_token_secret.should.equal 'token-secret'
    res = { body: { access_token: 'access-token' }, status: 200 }
    @request.end.args[0][0](null, res)

  it 'denies twitter signup', (done) ->
    cb = (err, user) ->
      err.message.should.containEql 'please sign up'
      done()
    cbs.twitter @req, 'foo-token', 'token-secret', { displayName: 'Craig' }, cb
    res = { body: { error_description: 'no account linked' }, status: 403 }
    @request.end.args[0][0](null, res)

  it 'passes the user agent through login', ->
    @req.get.returns 'chrome-foo'
    cbs.local @req, 'craig', 'foo'
    @request.set.args[0][0].should.containEql 'User-Agent': 'chrome-foo'
