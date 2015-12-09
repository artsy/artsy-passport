
describe '#submitTwitterLastStep', ->

  before ->
    opts = @artsyPassport.__get__ 'opts'
    @submitTwitterLastStep = @artsyPassport.__get__ 'submitTwitterLastStep'
    @request = @artsyPassport.__get__ 'request'
    @req = { query: {}, user: { get: -> 'access-foo-token' } }
    @res = { redirect: sinon.stub() }
    @next = sinon.stub()

  it 'creates a user', (done) ->
    @req.body = email: 'foo@bar.com', email_confirmation: 'foo@bar.com'
    @request.put = (url) ->
      url.should.containEql 'api/v1/me'
      send: (data) ->
        data.email.should.equal 'foo@bar.com'
        data.email_confirmation.should.equal 'foo@bar.com'
        done()
        end: ->
    @req.param = -> 'foo@bar.com'
    @submitTwitterLastStep @req, @res, @next

  it 'logs in the JSON from the PUT call'
