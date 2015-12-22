Backbone = require 'backbone'
rewire = require 'rewire'
sinon = require 'sinon'
{ serialize, deserialize } = mod = rewire '../../lib/passport/serializers'

describe '#serialize', ->

  beforeEach ->
    @request = {}
    @request.get = sinon.stub().returns @request
    @request.set = sinon.stub().returns @request
    @request.end = sinon.stub().returns @request
    mod.__set__ 'request', @request
    @resolveSerialize = =>
      @request.end.args[0][0](null, { body: { id: 'craig', foo: 'baz' } })
      @request.end.args[1][0](null, { body: [{ provider: 'facebook' }] })

  it 'only stores select data in the session', (done) ->
    user = new Backbone.Model({ id: 'craig', foo: 'baz', bam: 'bop' })
    serialize user, (err, data) ->
      (data.foo?).should.not.be.ok
      data.id.should.equal 'craig'
      done()
    @resolveSerialize()


  it 'add authentications', (done) ->
    user = new Backbone.Model({ id: 'craig', foo: 'baz', bam: 'bop' })
    serialize user, (err, data) ->
      data.authentications[0].provider.should.equal 'facebook'
      done()
    @resolveSerialize()

  it 'works when theres an error from Gravity', (done) ->
    user = new Backbone.Model({ id: 'craig', foo: 'baz', bam: 'bop' })
    serialize user, (err, data) ->
      err.message.should.equal 'fail'
      done()
    @request.end.args[0][0](null, { body: { id: 'craig', foo: 'baz' } })
    @request.end.args[1][0](new Error('fail'), null)

describe '#deserialize', ->

  it 'wraps the user data in a model', (done) ->
    mod.__set__ 'opts', CurrentUser: class User
      constructor: (@attrs) ->
    deserialize { id: 'craig', name: 'Craig' }, (err, user) ->
      user.attrs.name.should.equal 'Craig'
      done()
