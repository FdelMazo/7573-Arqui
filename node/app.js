// Load config
const config   = require('./config');

// Import libraries
const express         = require('express');
const got             = require('got');
const Redis           = require('ioredis');

// Waiting time and retries for Redis
const REDIS_WAIT_TIME_BASE = 60000 // Wait from 1 minute...
const REDIS_RESET_RETRIES = 5; // ... up to 5 minutes, then reset

// Setup cache keys
const cacheKeyPrefix = 'key-';

let redisClient;

(async () => {
  // Create redis client
  redisClient = await new Redis({
    host: config.redis.host,
    port: config.redis.port,
    password: config.redis.password,
    retryStrategy(times) {
      const waitingTime = REDIS_WAIT_TIME_BASE * (times % REDIS_RESET_RETRIES); 
      console.log('Could not connect to Redis, number of retries so far:', times, '- waiting', waitingTime, 'milliseconds');
      return waitingTime;
    }
  });
  redisClient.on('error', (e) => {
    if (e.code == 'ECONNREFUSED') {
      // Swallow error, will be dealt with by the retry strategy
      return
    }
    throw e;
  });
})();

// Initialize datadog client
const connectDatadog = require('connect-datadog')(config.datadog);

// Create app
const app = express();

// Set app to use the datadog middleware
app.use(connectDatadog);

// Routes
app.get('/', (req, res) => res.send('Hello World!'));
app.get('/remote', wrapped(getRemoteValue));
app.get('/alternate', wrapped(getAlternateValue));
app.get('/remote/cached', wrapped(getCached));
app.delete('/remote/cached', delCached);

// Start app
app.listen(3000, () => console.log('Example app listening on port 3000!'));

// --- Request handlers ---

function wrapped(handler) {
  return async (req, res) => {
    try {
      const response = await handler();
      res.status(200).set({"Cache-Control":"no-cache, no-store, must-revalidate"}).send(response);
    } catch (error) {
      res.status(500).send(error);
    }
  }
}

async function getRemoteValue() {
  const response = await got(`${config.remoteBaseUri}/sleep/1`);
  return response.body;
}

async function getAlternateValue() {
  const response = await got(`${config.alternateUrl}`);
  return response.body;
}

async function getCached() {
  // Id to be used just for debugging, to identify which request some logs belong to
  const reqId = Math.random().toString().slice(2, 11);
  const cacheKey = cacheKeyPrefix + Math.floor(Math.random()*config.cacheKeyLength);

  let value;
  debug(reqId, 'checking cache ['+cacheKey+']...');
  try {
    value = await redisClient.get(cacheKey);
  } catch (e) {
    console.log(reqId, 'error while querying Redis');
    throw 'Redis not available';
  }
  
  if (!value) {
    debug(reqId, 'hitting remote service to set cache...');
    value = await getRemoteValue();

    debug(reqId, 'setting cache (asynchronously)...');
    redisClient.set(cacheKey, value).then(() => debug(reqId, 'cache set.'));
  }

  debug(reqId, 'answering');
  return value;
}

async function delCached(req, res) {
  try {
    debug('deleting cache contents...');
    await redisClient.flushdb();
    res.status(204).send();
  } catch (error) {
    res.status(500).send(error);
  }
}

// --- helper functions ---

function debug(...args) {
  if (!config.debug) {
    return;
  }

  console.log(...args);
}
