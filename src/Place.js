const Util = require('./Util');

class Place {
    constructor() {
        this.id = Util.generateRandomString(30);
        this.response = null;
        this.commands = [];

        Place.instances[this.id] = this;
    }
    
    static getPlace(id) {
        if (Place.instances[id]) {
            return Place.instances[id];
        } else {
            throw 'Unknown place id!';
        }
    }

    reply() {
        if (this.commands.length === 0 || this.response === null) {
            return;
        }

        this.response.status(200).json(this.commands.shift()).end();
        this.response = null;
    }

    setResponse(res) {
        if (this.response !== null) {
            this.response.status(409).end();
            this.response = null;
        }

        this.response = res;
        
        if (this.commands.length > 0) {
            this.reply();
        } else {
            let currentResponse = this.response;
            setTimeout(() => {
                if (currentResponse === this.response) {
                    this.response.status(204).end();
                    this.response = null;
                }
            }, 5500);
        }
    }
}

Place.instances = {};

module.exports = Place;