_                  = require 'lodash'
async              = require 'async'
Meshblu            = require 'meshblu-http'
MeshbluConfig      = require 'meshblu-config'
MeshbluRulesEngine = require 'meshblu-rules-engine'
SimpleBenchmark    = require 'simple-benchmark'
cachedRequest      = require '../helpers/cached-request'
DeviceCache        = require '../helpers/cached-device'
debug              = require('debug')('command-and-control:message-service')
debugError         = require('debug')('command-and-control:user-errors')
debugSlow          = require('debug')("command-and-control:slow-requests")
RefResolver        = require 'meshblu-json-schema-resolver'

class MessageService
  constructor: ({ @data, @device, @meshbluAuth }) ->
    meshbluJSON = new MeshbluConfig().toJSON()
    @meshbluConfig = _.defaults(@meshbluAuth, meshbluJSON)
    commandAndControl = _.get @device, 'commandAndControl', {}
    @errorDevice = commandAndControl.errorDevice
    @rulesets ?= commandAndControl.rulesets ? @device.rulesets
    @meshblu = new Meshblu @meshbluConfig
    @benchmarks = {}
    SimpleBenchmark.resetIds()
    @SLOW_MS = process.env.SLOW_MS || 3000
    @deviceCache = new DeviceCache { @meshblu }
    @resolver = new RefResolver { @meshbluConfig }

  resolve: (callback) =>
    @resolver.resolve @device, (error, @device) =>
      callback error

  process: (callback) =>
    debug 'messageService.create'
    benchmark = new SimpleBenchmark { label: 'process:total' }
    done = (error) =>
      @benchmarks['process:total'] = "#{benchmark.elapsed()}ms"
      @_logSlowRequest() if benchmark.elapsed() > @SLOW_MS
      return callback @_errorHandler(error)

    @resolve (error) =>
      return callback error if error?

      async.map @rulesets, @_getRuleset, (error, rulesMap) =>
        return done error if error?
        async.map _.compact(_.flatten(rulesMap)), @_doRule, (error, results) =>
          return done error if error?
          commands = _.flatten results
          commands = @_mergeCommands commands
          async.each commands, @_doCommand, done

  _logSlowRequest: =>
    debugSlow(@meshbluAuth.uuid, 'benchmarks', @benchmarks)

  _mergeCommands: (commands) =>
    allUpdates = []
    mergedUpdates = {}
    _.each commands, (command) =>
      type = command.type
      uuid = command.params.uuid
      as = command.params.as
      operation = command.params.operation
      if type == 'meshblu' && operation != 'update'
        allUpdates.push command
        return

      key = _.compact([uuid, as, type, operation]).join('-')
      currentUpdate = mergedUpdates[key] ? command
      oldData = currentUpdate.params.data
      currentUpdate.params.data = _.merge oldData, command.params.data
      mergedUpdates[key] = currentUpdate

    return _.union allUpdates, _.values(mergedUpdates)

  _getRuleset: (ruleset, callback) =>
    return callback() unless ruleset.uuid?
    benchmark = new SimpleBenchmark { label: 'get-ruleset' }
    @deviceCache.get ruleset.uuid, (error, device) =>
      debug ruleset.uuid, error.message if error?.code == 404
      return callback @_addErrorContext(error, {ruleset}) if error?
      async.mapSeries device.rules, (rule, next) =>
        cachedRequest.get rule.url, (error, data) =>
          return next @_addErrorContext(error, {rule}), data
      , (error, rules) =>
        @benchmarks["get-ruleset:#{ruleset.uuid}"] = "#{benchmark.elapsed()}ms"
        return callback error, _.flatten rules

  _doRule: (rulesConfig, callback) =>
    benchmark = new SimpleBenchmark { labal: 'do-rules' }
    context = {@data, @device}
    engine = new MeshbluRulesEngine {@meshbluConfig, rulesConfig}
    engine.run context, (error, data) =>
      @_logInfo {rulesConfig, @data, @device}
      @benchmarks["do-rules"] ?= []
      @benchmarks["do-rules"].push "#{benchmark.elapsed()}ms"
      return callback @_addErrorContext(error, {rulesConfig, @data, @device}), data

  _doCommand: (command, callback) =>
    benchmark = new SimpleBenchmark { label: 'do-command' }
    done = (error) =>
      @benchmarks["do-command"] ?= []
      @benchmarks["do-command"].push "#{benchmark.elapsed()}ms"
      return callback @_addErrorContext(error, { command })
    return done new Error('unsupported command type') if command.type != 'meshblu'

    params  = _.get command, 'params', {}
    options = {}
    options.as = params.as if params.as?
    { operation } = params

    return @_meshbluUpdate params, options, done if operation == 'update'
    return @_meshbluMessage params, options, done if operation == 'message'
    return done new Error('unsupported operation type')

  _meshbluUpdate: (params, options, callback) =>
    { uuid, data } = params
    return callback new Error('undefined uuid') unless uuid?
    benchmark = new SimpleBenchmark { label: "meshblu:update:#{uuid}" }
    return @meshblu.updateDangerously uuid, data, options, (error) =>
      @benchmarks["meshblu:update:#{uuid}"] = "#{benchmark.elapsed()}ms"
      callback error

  _meshbluMessage: (params, options, callback) =>
    { message } = params
    return callback new Error('undefined message') unless message?
    devices = _.join message?.devices, ','
    benchmark = new SimpleBenchmark { label: "meshblu:message:#{devices}" }
    return @meshblu.message message, options, (error) =>
      @benchmarks["meshblu:message:#{devices}"] = "#{benchmark.elapsed()}ms"
      callback error

  _addErrorContext: (error, context) =>
    return unless error?
    error.context ?= {}
    error.context = _.merge error.context, context
    return error

  _errorHandler: (error) =>
    return unless error?
    @_sendError error
    error.code = 422
    return error

  _logInfo: ({rulesConfig, data, device}) =>
    return unless @errorDevice?
    return unless @errorDevice.logLevel == 'info'

    message =
      devices: [ @errorDevice.uuid ]
      input: {data, deviceUuid: @device.uuid, device, rulesConfig}

    @meshblu.message message, (error) =>
      return unless error?
      debug 'could not forward info message to meshblu'

  _sendError: (error) =>
    errorMessage =
      devices: [ @errorDevice?.uuid ]
      error:
        stack: error.stack?.split('\n')
        context: error.context
        code: error.code
      input: {@data, deviceUuid: @device.uuid}

    debugError JSON.stringify({errorMessage},null,2)
    return unless @errorDevice?
    errorMessage.input = {@data, @device}

    @meshblu.message errorMessage, (error) =>
      return unless error?
      debug 'could not forward error message to meshblu'

module.exports = MessageService
