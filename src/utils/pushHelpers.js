const db = require('../config/database')
const apn = require('apn')
const apnProvider = require('../config/apn')
require('dotenv').config()

const BUNDLE_ID = process.env.BUNDLE_ID || 'namgostar.KyleGPT'

function sendPush(recipientEmail, alertText) {
    db.get('SELECT token FROM device_tokens WHERE email = ?', [recipientEmail], (err, row) => {
        if (err || !row) {
            console.log(`No token found for ${recipientEmail}, skipping push.`)
            return
        }

        const note = new apn.Notification()
        note.expiry = Math.floor(Date.now() / 1000) + 3600
        note.badge = 1
        note.sound = 'ping.aiff'
        note.alert = alertText
        note.topic = BUNDLE_ID

        if (apnProvider) {
            apnProvider.send(note, row.token).then((result) => {
                if (result.sent.length > 0) {
                    console.log(`Push sent to ${recipientEmail}`)
                } else {
                    console.error('Push failed:', JSON.stringify(result.failed[0].response))
                }
            })
        } else {
            console.log(`Push generated but dropped (APN offline): ${alertText}`)
        }
    })
}

module.exports = {
    sendPush
}
