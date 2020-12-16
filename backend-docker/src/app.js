const { port } = require('./config');
const express = require('express')
const app = express()

console.log(`Port: ${port}`);

app.get('/', (req, res) => {
	console.log('GET /');
	res.send('Hello World!');
})

app.listen(port, () => {
	console.log(`Example app listening at http://localhost:${port} - V005`)
})
