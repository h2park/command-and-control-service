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

1. Create Ruleset device
1. Add webhook

### Create Ruleset Device
Using the command and control system requires a new Meshblu device called the `Ruleset`. The `Ruleset`
is a device that contains a list of URLs that point to the various rules that will be applied.

*Example Ruleset Device*
```json
{
  "name": "Ruleset",
  "type": "meshblu:ruleset",
  "rules": {
    "start-skype": {
      "key": "start-skype",
      "url": "https://raw.githubusercontent.com/octoblu/smartspaces-core-rules/master/start-skype/action.json"
    }
  }
}
```

See [meshblu-rules-engine](https://github.com/octoblu/meshblu-rules-engine) for the rules syntax.

### Add Webhook

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


# Usage

When the rules are applied to the an update may be applied to another device as a result.

*Example Output*
```json
{
  "uuid": "some-skype-uuid",
  "update": {
    "$set": {
      "inSkype": true
    }
  }
}
```

The update will be applied to the device with uuid `some-skype-uuid` and will change the `inSkype` property to `true`.

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
