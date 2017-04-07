{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'

shmock        = require 'shmock'
request       = require 'request'
enableDestroy = require 'server-destroy'
Redis         = require 'ioredis'
Server        = require '../../src/server'
RequestCache  = require '../../src/helpers/cached-request'
DeviceCache   = require '../../src/helpers/cached-device'
_ = require 'lodash'

describe 'POST /v1/messages', ->
  beforeEach (done) ->
    @redis = new Redis 'localhost', dropBufferSupport: true
    @redis.on 'ready', done

  beforeEach (done) ->
    new RequestCache({ @redis }).clearCache()
    new DeviceCache({ meshblu: true, @redis }).clearCache()
    @meshblu = shmock 0xd00d, [
      (req, res, next) =>
        { url, method, body } = req
        if url=='/messages' && method=='POST' && _.isEqual(body.devices, ['error-device'])
          @errorMessage = body
          return res.send(204)
        next()
    ]
    enableDestroy @meshblu

    @ruleServer = shmock 0xdddd
    enableDestroy @ruleServer

    serverOptions =
      port: undefined,
      disableLogging: true
      meshbluConfig:
        hostname: 'localhost'
        protocol: 'http'
        resolveSrv: false
        port: 0xd00d

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  afterEach ->
    @ruleServer.destroy()
    @meshblu.destroy()
    @server.destroy()

  beforeEach ->
    @userAuth = new Buffer('room-group-uuid:room-group-token').toString 'base64'

    @roomGroupDevice =
      uuid: 'room-group-uuid'
      rulesets: [
        uuid: 'ruleset-uuid'
      ]
      commandAndControl:
        errorDevice:
          uuid: 'error-device'

    @aRule =
      if:
        add:
          conditions:
            all: [{
              fact: 'device'
              path: '.genisys.currentMeeting'
              operator: 'exists'
              value: true
            },{
              fact: 'device'
              path: '.genisys.inSkype'
              operator: 'notEqual'
              value: true
            }]
          event:
            type: 'meshblu'
            params:
              uuid: "{{data.data.genisys.devices.activities}}"
              operation: 'update'
              data:
                $set:
                  "genisys.activities.startSkype.people": []
      else:
        add:
          conditions:
            all: [
              fact: 'data'
              operator: 'exists'
              value: true
            ]
          event:
            type: 'meshblu'
            params:
              uuid: "{{data.data.genisys.devices.activities}}"
              operation: 'update'
              data:
                $set:
                  "genisys.activities.startSkype.people": []
        message:
          conditions:
            all: [
              fact: 'data'
              operator: 'exists'
              value: true
            ]
          event:
            type: 'meshblu'
            params:
              operation: 'message'
              message:
                devices: ['erik-device']
                favoriteBand: 'santana'

    @bRule =
      if:
        add:
          conditions:
            all: [{
              fact: 'device'
              path: '.genisys.currentMeeting'
              operator: 'exists'
              value: true
            },{
              fact: 'device'
              path: '.genisys.inSkype'
              operator: 'notEqual'
              value: true
            }]
          event:
            type: 'meshblu'
            params:
              uuid: "{{data.data.genisys.devices.activities}}"
              operation: 'update'
              data:
                $set:
                  "genisys.activities.startSkype.people": []
      else:
        set:
          conditions:
            all: [
              fact: 'data'
              operator: 'exists'
              value: true
            ]
          event:
            type: 'meshblu'
            params:
              uuid: "{{data.data.genisys.devices.activities}}"
              operation: 'update'
              data:
                $set:
                  "genisys.activities.startSkypeAlso.people": []

    @rulesetDevice =
      uuid: 'ruleset-uuid'
      type: 'meshblu:ruleset'
      rules: [
        { url: "http://localhost:#{0xdddd}/rules/a-rule.json" }
        { url: "http://localhost:#{0xdddd}/rules/b-rule.json" }
      ]

    @options =
      uri: '/v1/messages'
      baseUrl: "http://localhost:#{@serverPort}"
      auth:
        username: 'room-group-uuid'
        password: 'room-group-token'
      json:
        data:
          uuid: 'room-uuid'
          genisys:
            devices:
              activities: 'activities-device-uuid'

    {@error, @response, @body} = {}

    @messageErikDeviceResponseCode ?= 204

    @setupShmocks = ()->
      @getARule = @ruleServer
        .get '/rules/a-rule.json'
        .reply 200, @aRule

      @getBRule = @ruleServer
        .get '/rules/b-rule.json'
        .reply 200, @bRule

      @authDevice = @meshblu
        .get '/v2/whoami'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 200, @roomGroupDevice

      @getRulesetDevice = @meshblu
        .get '/v2/devices/ruleset-uuid'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 200, @rulesetDevice

      @updateActivitiesDevice = @meshblu
        .put '/v2/devices/activities-device-uuid'
        .send {
          $set:
            "genisys.activities.startSkype.people": []
            "genisys.activities.startSkypeAlso.people": []
        }
        .reply 204

      @messageErikDevice = @meshblu
        .post '/messages'
        .send {
          devices: ['erik-device']
          favoriteBand: 'santana'
        }
        .reply @messageErikDeviceResponseCode

    @performRequest = (done) ->
      @setupShmocks()
      request.post @options, (@error, @response, @body) =>
        setTimeout =>
          done()
        , 100

  describe 'When everything works', ->
    beforeEach (done) ->
      @performRequest done

    it 'should return a 200', ->
      console.log @response.body
      expect(@response.statusCode).to.equal 200

    it 'should not have an @errorMessage', ->
      expect(@errorMessage).not.to.exist

    it 'should auth the request with meshblu', ->
      @authDevice.done()

    it 'should fetch the ruleset device', ->
      @getRulesetDevice.done()

    it 'should get the rule url', ->
      @getARule.done()
      @getBRule.done()

    it 'should update the activities device', ->
      @updateActivitiesDevice.done()

    it 'should message Erik about his favorite band', ->
      @messageErikDevice.done()

  describe 'When everything works and the logLevel is "info"', ->
    beforeEach (done) ->
      @roomGroupDevice.commandAndControl.errorDevice.logLevel = 'info'
      @performRequest done

    it 'should return a 200', ->
      expect(@response.statusCode).to.equal 200

    it 'should log an errorMessage', ->
      expect(@errorMessage).to.exist

  describe 'When everything works and we have no error message device', ->
    beforeEach (done) ->
      delete @roomGroupDevice.commandAndControl
      @performRequest done

    it 'should return a 200', ->
      expect(@response.statusCode).to.equal 200

  describe 'When we have an invalid ruleSet uuid', ->
    beforeEach (done) ->
      @roomGroupDevice.rulesets = [{uuid: 'unknown-uuid'}]
      @performRequest done

    it 'should return a 422', ->
      expect(@response.statusCode).to.equal 422

    it 'should contain the ruleset uuid in the error message', ->
      expect(@errorMessage.error.context).to.deep.equal ruleset: uuid: 'unknown-uuid'

  describe 'When we have an invalid ruleSet uuid and no error message device', ->
    beforeEach (done) ->
      @roomGroupDevice.rulesets = [{uuid: 'unknown-uuid'}]
      delete @roomGroupDevice.commandAndControl
      @performRequest done

    it 'should return a 422', ->
      expect(@response.statusCode).to.equal 422

  describe 'When we have an invalid rule in the ruleSet', ->
    beforeEach (done) ->
      @badRule = { url: "http://localhost:#{0xdddd}/rules/c-rule.json" }
      @rulesetDevice.rules.push @badRule
      @performRequest done

    it 'should return a 422', ->
      expect(@response.statusCode).to.equal 422

    it 'should contain the rule url in the error message', ->
      expect(@errorMessage.error.context).to.deep.equal rule: @badRule

  describe 'When we update a device without a uuid', ->
    beforeEach (done) ->
      delete @options.json.data.genisys.devices.activities
      @performRequest done

    it 'should return a 422', ->
      expect(@response.statusCode).to.equal 422

    it 'should reference the failed command in the error message', ->
      expect(@errorMessage.error.context.command).to.exist

  describe 'When we message a device but get a 403', ->
    beforeEach (done) ->
      @messageErikDeviceResponseCode = 403
      @performRequest done

    it 'should return a 422', ->
      expect(@response.statusCode).to.equal 422

    it 'should reference the failed command in the error message', ->
      expect(@errorMessage.error.context.command).to.exist

    it 'should have a 403 code in the error', ->
      expect(@errorMessage.error.code).to.equal 403
