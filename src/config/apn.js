const apn = require('apn')
require('dotenv').config()

const KEY_ID = process.env.APN_KEY_ID;
const TEAM_ID = process.env.APN_TEAM_ID;

let apnProvider = null

try {
    apnProvider = new apn.Provider({
        token: {
            key: 'authkey.p8',
            keyId: KEY_ID,
            teamId: TEAM_ID
        },
        production: true
    })
} catch (e) {
    console.error('APN init failed:', e.message)
}

module.exports = apnProvider
