describe '#logout', ->

  beforeEach ->
    @send = sinon.stub().returns(end: (cb) -> cb())
    @del = sinon.stub().returns(send: @send)
    @logout = @artsyPassport.__get__ 'logout'
    @req = {
      query: {}
      get: (-> 'access-foo-token')
      logout: (=> @req.user = null)
      user: { get: -> 'secret' }
    }
    @res = { send: sinon.stub() }
    @logoutSpy = sinon.spy(@req, 'logout');
    @next = sinon.stub()

  it 'logs out, deletes the auth token, and redirects home', ->
    @artsyPassport.__set__ 'request', del: @del
    @logout @req, @res, @next
    @logoutSpy.called.should.be.true
    @del.args[0][0].should.containEql '/api/v1/access_token'
    @send.args[0][0].should.eql access_token: 'secret'
    (@req.user?).should.not.be.ok
    @next.called.should.be.true

  it 'logs out, deletes the auth token, and redirects home', ->
    @artsyPassport.__set__ 'request', del: -> send: -> end: (cb) ->
      cb({ error: true }, { code: 500, error: 'Fake error', ok: false })
    @logout @req, @res, @next
    @next.called.should.be.true

  it 'still works if there is no access token', ->
    @req.user = undefined
    @logout @req, @res, @next
    @logoutSpy.called.should.be.true
    (@req.user?).should.not.be.ok
    @del.called.should.not.be.ok
    @next.called.should.be.true
