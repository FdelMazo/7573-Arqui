module.exports = {
  // Flag to determine whether to log debug information or not
  debug: true,

  // Number of cache keys
  cacheKeyLength:  10,

  // Base uri for remote python service
  remoteBaseUri: '',

  // URL for alternate service
  alternateUrl: '',

  // Options for creating redis client
  redis: {
    host: '',
    port: '6379',
    password: ''
  },

  datadog: {
    'response_code': true,
    'tags':          ['app:node']
  },
};
