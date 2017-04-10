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

describe 'POST /v1/messages?timestampPath=meshblu.updatedAt', ->
  beforeEach (done) ->
    @redis = new Redis 'localhost', keyPrefix: 'command-and-control:', dropBufferSupport: true
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
              uuid: "{{data.genisys.devices.activities}}"
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
              uuid: "{{data.genisys.devices.activities}}"
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
              uuid: "{{data.genisys.devices.activities}}"
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
              uuid: "{{data.genisys.devices.activities}}"
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
      qs:
        timestampPath: 'meshblu.updatedAt'
      auth:
        username: 'room-group-uuid'
        password: 'room-group-token'
      json:
        uuid: 'room-uuid'
        genisys:
          devices:
            activities: 'activities-device-uuid'
        meshblu:
          updatedAt: '2010-04-04T00:00:00Z'

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

    @performRequest = (done) ->
      @setupShmocks()
      request.post @options, (@error, @response, @body) =>
        setTimeout =>
          done()
        , 100

  describe 'When everything works', ->
    beforeEach (done) ->
      @redis.set 'cache:timestamp:room-group-uuid', JSON.stringify('2017-04-06T00:00:00Z'), done
      return

    beforeEach (done) ->
      @performRequest done

    it 'should return a 202', ->
      console.log @response.body if @errorMessage?
      expect(@response.statusCode).to.equal 202
      expect(@errorMessage).not.to.exist
      @authDevice.done()
