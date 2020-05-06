Backbone = require 'backbone'
rewire = require 'rewire'
sinon = require 'sinon'
cbs = rewire '../../lib/passport/callbacks'

describe 'passport callbacks', ->

  beforeEach ->
    @req = { get: sinon.stub() }
    @request = {}
    @request.get = sinon.stub().returns @request
    @request.query = sinon.stub().returns @request
    @request.set = sinon.stub().returns @request
    @request.end = sinon.stub().returns @request
    @request.post = sinon.stub().returns @request
    @request.send = sinon.stub().returns @request
    cbs.__set__ 'request', @request
    cbs.__set__ 'opts', {
      ARTSY_ID: 'artsy-id'
      ARTSY_SECRET: 'artsy-secret'
      ARTSY_URL: 'http://apiz.artsy.net'
      CurrentUser: Backbone.Model
    }

  it 'gets a user with an access token email/password/otp', (done) ->
    cbs.local @req, 'craig', 'foo', '123456', (err, user) ->
      user.get('accessToken').should.equal 'access-token'
      done()
    @request.post.args[0][0].should
      .equal 'http://apiz.artsy.net/oauth2/access_token'
    res = { body: { access_token: 'access-token' }, status: 200 }
    @request.end.args[0][0](null, res)

  it 'gets a user with an access token email/password without otp', (done) ->
    cbs.local @req, 'craig', 'foo', null, (err, user) ->
      user.get('accessToken').should.equal 'access-token'
      done()
    @request.post.args[0][0].should
      .equal 'http://apiz.artsy.net/oauth2/access_token'
    res = { body: { access_token: 'access-token' }, status: 200 }
    @request.end.args[0][0](null, res)

  it 'gets a user with an access token facebook', (done) ->
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

  it 'gets a user with an access token apple', (done) ->
    cbs.apple @req, 'foo-token', 'refresh-token', { id: 'some-apple-uid' }, (err, user) ->
      user.get('accessToken').should.equal 'access-token'
      done()
    @request.post.args[0][0].should
      .equal 'http://apiz.artsy.net/oauth2/access_token'
    queryParams = @request.query.args[0][0]
    queryParams.grant_type.should.equal 'apple_uid'
    queryParams.apple_uid.should.equal 'some-apple-uid'
    res = { body: { access_token: 'access-token' }, status: 200 }
    @request.end.args[0][0](null, res)

  it 'passes the user agent through login', ->
    @req.get.returns 'chrome-foo'
    cbs.local @req, 'craig', 'foo'
    @request.set.args[0][0].should.containEql { 'User-Agent': 'chrome-foo' }

  it 'passes the user agent through facebook signup', ->
    @req.get.returns 'foo-bar-baz-ua'
    cbs.facebook @req, 'foo-token', 'token-secret', { displayName: 'Craig' }
    res = { body: { error_description: 'no account linked' }, status: 403 }
    @request.end.args[0][0](null, res)
    @request.set.args[1][0]['User-Agent'].should.equal 'foo-bar-baz-ua'

  it 'passes the user agent through apple signup', ->
    @req.get.returns 'foo-bar-baz-ua'
    cbs.apple @req, 'foo-token', 'refresh-token', 'id-token', {}
    res = { body: { error_description: 'no account linked' }, status: 403 }
    @request.end.args[0][0](null, res)
    @request.set.args[1][0]['User-Agent'].should.equal 'foo-bar-baz-ua'
