sinon = require 'sinon'
rewire = require 'rewire'
analytics = rewire '../../lib/app/analytics'

describe 'analytics', ->

  beforeEach ->
    analytics.__set__ 'opts', SEGMENT_WRITE_KEY: 'foobar'
    scope = this
    analytics.__set__ 'Analytics', class Analytics
      constructor: ->
        scope.analytics = this
      track: sinon.stub()
    @req = { session: {}, query: {}, user: { get: -> 'foo' } }
    @res = { locals: { sd: {} } }
    @next = sinon.stub()

  it 'tracks signup', ->
    analytics.trackSignup('email') @req, @res, @next
    @analytics.track.args[0][0].properties.signup_service.should.equal 'email'

  it 'passes modal id along', ->
    @req.session.modalId = 'moo'
    analytics.trackSignup('email') @req, @res, @next
    @analytics.track.args[0][0].properties.modal_id.should.equal 'moo'