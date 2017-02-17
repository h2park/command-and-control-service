# command-and-control-service

[![Dependency status](http://img.shields.io/david/octoblu/command-and-control-service.svg?style=flat)](https://david-dm.org/octoblu/command-and-control-service)
[![devDependency Status](http://img.shields.io/david/dev/octoblu/command-and-control-service.svg?style=flat)](https://david-dm.org/octoblu/command-and-control-service#info=devDependencies)
[![Build Status](http://img.shields.io/travis/octoblu/command-and-control-service.svg?style=flat)](https://travis-ci.org/octoblu/command-and-control-service)

[![NPM](https://nodei.co/npm/command-and-control-service.svg?style=flat)](https://npmjs.org/package/command-and-control-service)

# Table of Contents

* [Introduction](#introduction)
* [Getting Started](#getting-started)
* [Usage](#usage)
  * [Install](#install)
  * [Default](#default)
  * [Docker](#docker)
    * [Development](#development)
    * [Production](#production)
  * [Debugging](#debugging)
  * [Test](#test)
* [License](#license)

# Introduction

The command and control service allows rules to be applied to messages or configuration changes
on a Meshblu device and perform updates on another.

# Getting Started

1. Create a Rule file
1. Create Ruleset device
1. Add webhook and properties

### Create a Rule file

The [meshblu-rules-engine](https://github.com/octoblu/meshblu-rules-engine) is based on processing rules from
the [JSON Rules Engine](https://github.com/cachecontrol/json-rules-engine).

Meshblu-rules-engine processes rules in the basic format of:

```json
{
  "if": {...rules...},
  "else": {...rules...}
}
```

where the "else" block is processed only if no conditions are true in the "if" block.

See an example in [smartspaces-core-rules](https://github.com/octoblu/smartspaces-core-rules/blob/master/hue-button-start-meeting-or-skype/action.json).

Events should be in format:

```json
{
  "type": "meshblu",
  "params": {
    "operation": "message",
    "as": optional,
    "message": {
      "devices": [ ... ],
      ...
    }
  }
}

or

{
  "type": "meshblu",
  "params": {
    "operation": "update",
    "as": optional,
    "uuid": required,
    "data": {
      ...
    }
  }
}  
```

### Create Ruleset Device
Using the command and control system requires a new Meshblu device called the `Ruleset`. The `Ruleset`
is a device that contains a list of URLs that point to the various rules that will be applied.

*Example Ruleset Device*
```json
{
  "name": "Ruleset",
  "type": "meshblu:ruleset",
  "rules": [
    {
      "url": "https://raw.githubusercontent.com/octoblu/smartspaces-core-rules/master/hue-button-start-meeting-or-skype/action.json"
    }
  ]
}
```

### Add Webhook and properties

On the device that will have the rules applied to it, you will need to set up a webhook to forward events to the command and control service.

*Example Webhook*
```json
{
  "name": "My Device",
  "meshblu": {
    "forwarders": {
      "version": "2.0.0",
      "broadcast": {
        "sent": [
          {
            "type": "webhook",
            "url": "https://command-and-control.octoblu.com/v1/messages",
            "method": "POST",
            "generateAndForwardMeshbluCredentials": true
          }
        ]
      },
      "configure": {
        "sent": [
          {
            "type": "webhook",
            "url": "https://command-and-control.octoblu.com/v1/messages",
            "method": "POST",
            "generateAndForwardMeshbluCredentials": true
          }
        ]
      }
    }
  }
}
```

The webhooked device should also be configured with a "commandAndControl.rulesets" property to point to the newly created Ruleset device:

```json
{
  "commandAndControl": {
    "rulesets": [
      {
        "uuid": rule-set-device-uuuid
      }
    ],
    "errorDevice": {
      "uuid": "error-device-uuid",
      "logLevel": "error"
    }
  }
}
```

An optional "errorDevice" property will forward errors from the command-and-control-service to the error device. The property `logLevel` can be one of `error`/`info`, and defaults to `error`. When set to `error`, the device will only be notified about rule enforcements that resulted in an error. When set to `info`, all rule enforcements will be sent to the device.

Note: Previously, there was an `errorDeviceId` property that could be used to register a device for update notifications. This property has been deprecated, and will result in a deprecation notice being sent to that device until March 1st 2017, when it will ignored entirely.


## Install

```bash
git clone https://github.com/octoblu/command-and-control-service.git
cd /path/to/command-and-control-service
npm install
```

## Default

```javascript
node command.js
```

## Docker

### Development

```bash
docker build -t local/command-and-control-service .
docker run --rm -it --name command-and-control-service-local -p 8888:80 local/command-and-control-service
```

### Production

```bash
docker pull quay.io/octoblu/command-and-control-service
docker run --rm -p 8888:80 quay.io/octoblu/command-and-control-service
```

## Debugging

```bash
env DEBUG='command-and-control-service*' node command.js
```

```bash
env DEBUG='command-and-control-service*' node command.js
```

## Test

```bash
npm test
```

## License

The MIT License (MIT)

Copyright (c) 2016 Octoblu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
