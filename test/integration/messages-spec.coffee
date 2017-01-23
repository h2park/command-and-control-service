shmock        = require 'shmock'
request       = require 'request'
enableDestroy = require 'server-destroy'
Server        = require '../../src/server'

describe 'POST /v1/messages', ->
  beforeEach (done) ->
    @meshblu = shmock 0xd00d
    enableDestroy @meshblu

    @ruleServer = shmock 0xdddd
    enableDestroy @ruleServer

    @logFn = sinon.spy()
    serverOptions =
      port: undefined,
      disableLogging: true
      logFn: @logFn
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

  describe 'When everything works', ->
    beforeEach (done) ->
      userAuth = new Buffer('room-group-uuid:room-group-token').toString 'base64'

      roomGroupDevice =
        uuid: 'room-group-uuid'
        rulesets: [
          uuid: 'ruleset-uuid'
        ]

      rule =
        rules:
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
                uuid: "{{genisys.devices.activities}}"
                operation: 'update'
                data:
                  $set:
                    "genisys.activities.startSkype":
                      title: "Start Skype",
                      jobType: "start-skype",
                      meetingId: "{{genisys.currentMeeting.meetingId}}",
                      people: "{{genisys.people.byAttendee.isAttendee}}"
        noevents: [
          type: 'meshblu'
          params:
            uuid: "{{genisys.devices.activities}}"
            operation: 'update'
            data:
              $set:
                "genisys.activities.startSkype.people": []
        ]

      @getRule = @ruleServer
        .get '/rules/a-rule.json'
        .reply 200, rule

      rulesetDevice =
        uuid: 'ruleset-uuid'
        type: 'meshblu:ruleset'
        rules: [
          url: "http://localhost:#{0xdddd}/rules/a-rule.json"
        ]

      @authDevice = @meshblu
        .get '/v2/whoami'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 200, roomGroupDevice

      @getRulesetDevice = @meshblu
        .get '/v2/devices/ruleset-uuid'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 200, rulesetDevice

      @updateActivitiesDevice = @meshblu
        .put '/v2/devices/activities-device-uuid'
        .send {
          $set:
            "genisys.activities.startSkype.people": []
        }
        .reply 204

      options =
        uri: '/v1/messages'
        baseUrl: "http://localhost:#{@serverPort}"
        auth:
          username: 'room-group-uuid'
          password: 'room-group-token'
        json:
          uuid: 'room-uuid'
          genisys:
            devices:
              activities: 'activities-device-uuid'

      request.post options, (error, @response, @body) =>
        console.log @body if @response.statusCode > 399
        done error

    it 'should return a 200', ->
      expect(@response.statusCode).to.equal 200

    it 'should auth the request with meshblu', ->
      @authDevice.done()

    it 'should fetch the ruleset device', ->
      @getRulesetDevice.done()

    it 'should get the rule url', ->
      @getRule.done()

    it 'should update the activities device', ->
      @updateActivitiesDevice.done()
