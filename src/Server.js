const express = require('express');
const bodyParser = require('body-parser');
const config = require('./config');

const Place = require('./Place');

let http = express();
http.use(bodyParser.json({ limit: '50mb' }));

http.get('/new', (req, res) => {
    let place = new Place();
    res.status(201).send(place.id).end();
});

http.get('/get/:id', (req, res) => {
    let place = Place.getPlace(req.params.id);
    place.setResponse(res);
});

http.post('/delete/:id', (req, res) => {
    
});

http.post('/write/:id/:action', (req, res) => {

});

http.listen(config.PORT);