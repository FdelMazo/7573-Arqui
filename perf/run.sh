#!/bin/bash
export TARGET=http://$(cat ../node/lb_dns)
export DATADOG_API_KEY=b03559c436823f4d51d6e33d4d5d36dd
export DEBUG=plugin:publish-metrics:datadog-statsd
npm run artillery run $1.yaml
