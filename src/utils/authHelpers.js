const db = require('../config/database')
require('dotenv').config()

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com';

function verifyChatOwnership(chatId, userEmail, callback) {
    db.get('SELECT userEmail FROM chats WHERE chatId = ?', [chatId], (err, row) => {
        if (err) return callback(err, false)
        if (!row) return callback(null, false)

        let isAdmin = (row.userEmail === ADMIN_EMAIL) || (userEmail === ADMIN_EMAIL);

        callback(null, row.userEmail === userEmail || isAdmin)
    })
}

module.exports = {
    verifyChatOwnership
}
