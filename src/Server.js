'use strict'

const express = require('express')
const bodyParser = require('body-parser')
const config = require('./config')

const Place = require('./Place')

let http = express()
http.use(bodyParser.json({ limit: '50mb' }))

http.get('/new', (req, res) => {
  console.log(req.originalUrl)
  let place = new Place()
  res.status(201).send({ status: 'OK', build: config.BUILD, placeId: place.id }).end()
})

http.get('/get/:id', (req, res) => {
  console.log(req.originalUrl)
  let place = Place.getPlace(req.params.id)
  place.setResponse(res)
})

http.post('/delete/:id', (req, res) => {
  console.log(req.originalUrl)
})

http.post('/write/:action/:id', (req, res) => {
  console.log(req.originalUrl)
})

http.listen(config.PORT)
