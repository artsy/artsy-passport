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
    @req = { session: {}, body: {}, user: { get: -> 'foo' } }
    @res = { locals: { sd: {} } }
    @next = sinon.stub()

  it 'tracks signup', ->
    analytics.trackSignup('email') @req, @res, @next
    @analytics.track.args[0][0].properties.signup_service.should.equal 'email'

  it 'passes along modal_id and acquisition_initiative submitted fields', ->
    @req.body.modal_id = 'foo'
    @req.body.acquisition_initiative = 'bar'
    analytics.setCampaign @req, @res, @next
    analytics.trackSignup('email') @req, @res, @next
    @analytics.track.args[0][0].properties
      .modal_id.should.equal 'foo'
    @analytics.track.args[0][0].properties
      .acquisition_initiative.should.equal 'bar'

  it 'doesnt hold on to the temporary session variable', ->
    analytics.__set__ 'opts', {}
    @req.body.modal_id = 'foo'
    @req.body.acquisition_initiative = 'bar'
    analytics.setCampaign @req, @res, @next
    analytics.trackSignup('email') @req, @res, @next
    Object.keys(@req.session).length.should.equal 0
