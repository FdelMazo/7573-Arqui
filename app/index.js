const { default: axios } = require('axios');
const express = require('express')
const SDC = require('statsd-client')
const app = express()
const port = 3000
const url_sync = 'http://bbox:9090/'
const url_async = 'http://bbox:9091/'
const random = Math.round(Math.random() * 100, 1)

const sdc = new SDC({
    host: 'graphite',
    port: 8125
})


app.use(sdc.helpers.getExpressMiddleware('requests', { timeByUrl: true }));

/*
const metrics = (endpoint) => {
    const begin = new Date()
    sdc.timing(`node.${endpoint}.request-time`, begin)
    sdc.increment(`node.${endpoint}.request-count`)
}
*/

// http://ajennings.net/blog/a-million-digits-of-pi-in-9-lines-of-javascript.html
// http://ajennings.net/pi.html
const pi = (digits) => {
    let i = 1n;
    let x = 3n * (10n ** (BigInt(digits) + 20n));
    let pi = x;
    while (x > 0) {
        x = x * i / ((i + 1n) * 4n);
        pi += x / (i + 2n);
        i += 2n;
    }
    return (pi / (10n ** 20n))
}

app.get('/ping', (req, res) => {
    //metrics('ping')
    res.status(200).send(`[${random}] pong\n`)
})

app.get('/work', (req, res) => {
    //metrics('work')
    const n_thousand_digits = req.query.n || 15
    const r = pi(n_thousand_digits * 1000).toString()
    res.status(200).send(r.toString() + '\n')
})

app.get('/sync', (req, res) => {
    //metrics('sync')
    axios.get(url_sync).then(res_service => {
        res.status(200).send(`Res sync service\n ${res_service.data}\n`)
    })
})

app.get('/async', (req, res) => {
    //metrics('async')
    axios.get(url_async).then(res_service => {
        res.status(200).send(`Res async service\n ${res_service.data}\n`)
    })
})

app.listen(port, () => {})
