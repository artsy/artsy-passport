Backbone = require 'backbone'
rewire = require 'rewire'
sinon = require 'sinon'
cbs = rewire '../../lib/passport/callbacks'

describe '#local', ->

  beforeEach ->
    @req = {}
    @request = {}
    @request.get = sinon.stub().returns @request
    @request.query = sinon.stub().returns @request
    @request.set = sinon.stub().returns @request
    @request.end = sinon.stub().returns @request
    cbs.__set__ 'request', @request
    cbs.__set__ 'opts',
      ARTSY_ID: 'artsy-id'
      ARTSY_SECRET: 'artsy-secret'
      ARTSY_URL: 'http://apiz.artsy.net'
      CurrentUser: Backbone.Model

  it 'gets an access token via email/password', (done) ->
    cbs.local @req, 'craig', 'foo', (err, user) ->
      user.get('accessToken').should.equal
      done()
    @request.get.args[0][0].should
      .equal 'http://apiz.artsy.net/oauth2/access_token'
    res = { body: { access_token: 'access-token' }, status: 200 }
    @request.end.args[0][0](null, res)
