#!/bin/bash
export TARGET=http://$(cat ../node/lb_dns)
export DATADOG_API_KEY=""
export DEBUG=http,http:response,plugin:publish-metrics:datadog-statsd
export ENDPOINT=${1:-"/"}
npm run artillery run ping.yaml
npm run artillery run scenario.yaml
