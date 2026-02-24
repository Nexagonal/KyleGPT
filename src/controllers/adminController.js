const db = require('../config/database')
const { formatMessages } = require('../utils/formatters')
require('dotenv').config()

const listAllChats = (req, res) => {
    const sql = `
        SELECT 
            c.chatId, c.userEmail, c.title, c.createdAt, c.deletedByUser, c.adminLastReadTimestamp,
            COALESCE(m.latestTimestamp, 0) as latestMessageTimestamp,
            COALESCE(m.messageCount, 0) as messageCount,
            u.nickname, u.email as authEmail
        FROM chats c
        LEFT JOIN users u ON c.userEmail = u.email
        LEFT JOIN (
            SELECT chatId, MAX(timestamp) as latestTimestamp, COUNT(*) as messageCount
            FROM messages
            GROUP BY chatId
        ) m ON c.chatId = m.chatId
        ORDER BY COALESCE(m.latestTimestamp, c.createdAt) DESC
    `

    db.all(sql, (err, rows) => {
        if (err) return res.status(500).json({ error: err.message })

        const grouped = {};
        (rows || []).forEach(row => {
            const displayId = row.userEmail
            if (!grouped[displayId]) {
                grouped[displayId] = {
                    userEmail: row.authEmail || row.userEmail,
                    nickname: row.nickname || 'Unknown',
                    chats: [],
                    latestActivity: 0
                }
            }
            const activityTime = row.latestMessageTimestamp || row.createdAt
            if (activityTime > grouped[displayId].latestActivity) {
                grouped[displayId].latestActivity = activityTime
            }
            grouped[displayId].chats.push({
                chatId: row.chatId,
                title: row.title,
                createdAt: row.createdAt,
                deletedByUser: row.deletedByUser === 1,
                latestMessageTimestamp: row.latestMessageTimestamp,
                messageCount: row.messageCount,
                isUnread: row.latestMessageTimestamp > row.adminLastReadTimestamp
            })
        })

        const users = Object.values(grouped).sort((a, b) => b.latestActivity - a.latestActivity)
        res.json({ users })
    })
}

const exportMessages = (req, res) => {
    const sql = 'SELECT * FROM messages ORDER BY timestamp ASC'
    db.all(sql, [], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message })
        res.json({ documents: formatMessages(rows) })
    })
}

const updateStatus = (req, res) => {
    const fields = req.body.fields
    const room = req.query.room || 'admin_heartbeat'
    const lastActive = fields.lastActive.doubleValue

    const sql = 'INSERT OR REPLACE INTO status (room, lastActive) VALUES (?, ?)'
    db.run(sql, [room, lastActive], (err) => {
        if (err) return res.status(500).json({ error: err.message })
        res.json({ status: 'Heartbeat Updated' })
    })
}

const getStatus = (req, res) => {
    const room = req.query.room || 'admin_heartbeat'

    db.get('SELECT lastActive FROM status WHERE room = ?', [room], (err, row) => {
        if (err) return res.status(500).json({ error: err.message })

        if (row) {
            res.json({ fields: { lastActive: { doubleValue: row.lastActive } } })
        } else {
            res.json({})
        }
    })
}

const adminReadChat = (req, res) => {
    const { chatId } = req.params
    const now = Date.now() / 1000

    db.run('UPDATE chats SET adminLastReadTimestamp = ? WHERE chatId = ?', [now, chatId], function (err) {
        if (err) return res.status(500).json({ error: err.message })
        res.json({ status: 'Marked as read' })
    })
}

module.exports = {
    listAllChats,
    exportMessages,
    updateStatus,
    getStatus,
    adminReadChat
}
