const express = require('express')
const app = express()
const port = 3000

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
    res.status(200).send('pong\n')
})

app.get('/work', (req, res) => {
    const n_thousand_digits = req.query.n || 15
    const r = pi(n_thousand_digits * 1000).toString()
    res.status(200).send(r.toString())
})

app.listen(port, () => {
    console.log(`Listening on port ${port}`)
})
