describe '#headerLogin', ->

  beforeEach ->
    opts = @artsyPassport.__get__ 'opts'
    opts.CurrentUser = Backbone.Model
    @headerLogin = @artsyPassport.__get__ 'headerLogin'
    @req = { query: {}, get: (-> 'access-foo-token'), login: sinon.stub() }
    @res = { send: sinon.stub() }
    @next = sinon.stub()

  it 'logs in a user if they pass their access token as a header', ->
    @headerLogin @req, @res, @next
    @req.login.args[0][0].get('accessToken').should.equal 'access-foo-token'

  it 'does not log in a user on sign out', ->
    @req.path = '/users/sign_out'
    @headerLogin @req, @res, @next
    @next.called.should.equal true

describe 'trustTokenLogin', ->
  beforeEach ->
    opts = @artsyPassport.__get__ 'opts'
    opts.CurrentUser = Backbone.Model
    @trustTokenLogin = @artsyPassport.__get__ 'trustTokenLogin'
    @__request__ = @artsyPassport.__get__ 'request'
    @request = {}
    @request.post = sinon.stub().returns @request
    @request.send = sinon.stub().returns @request
    @request.end = sinon.stub().returns @request
    @artsyPassport.__set__ 'request', @request

  afterEach ->
    @artsyPassport.__set__ 'request', @__request__

  it 'immediately nexts if there is no trust_token query param', ->
    req = query: {}, url: '/target-path'
    res = redirect: sinon.stub()
    next = sinon.stub()
    @trustTokenLogin req, res, next
    @request.post.called.should.be.false()
    next.called.should.be.true()
    res.redirect.called.should.be.false()

  it 'logs the user in when there is a trust_token present, redirecting to \
      a url sans trust_token param', ->
    req =
      login: sinon.stub().yields null
      query: trust_token: 'xxxx'
      url: '/target-path?trust_token=xxxx'
    res = redirect: sinon.stub()
    next = sinon.stub()
    @request.end.yields null, ok: true, body: access_token: 'yyy'
    @trustTokenLogin req, res, next
    @request.post.called.should.be.true()
    @request.send.args[0][0].code.should.equal 'xxxx'
    res.redirect.called.should.be.true()
    res.redirect.args[0][0].should.equal '/target-path'

  it 'preserves any other query string params', ->
    req =
      login: sinon.stub().yields null
      query: trust_token: 'xxxx', foo: 'bar', bar: 'baz'
      url: '/target-path?foo=bar&trust_token=xxxx&bar=baz'
    res = redirect: sinon.stub()
    next = sinon.stub()
    @request.end.yields null, ok: true, body: access_token: 'yyy'
    @trustTokenLogin req, res, next
    res.redirect.args[0][0].should.equal '/target-path?foo=bar&bar=baz'

  it 'nexts on failed code response', ->
    req =
      query: trust_token: 'xxxx'
      url: '/target-path?trust_token=xxxx'
    res = redirect: sinon.stub()
    next = sinon.stub()
    @request.end.yields 'err', null
    @trustTokenLogin req, res, next
    next.called.should.be.true()
    res.redirect.called.should.be.false()