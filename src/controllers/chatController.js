const db = require('../config/database')
const { formatMessages, truncateTitle } = require('../utils/formatters')
const { sendPush } = require('../utils/pushHelpers')
const { verifyChatOwnership } = require('../utils/authHelpers')
const crypto = require('crypto')
require('dotenv').config()

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com';

const getMessages = (req, res) => {
    const chatId = req.query.chatId
    const limit = Math.min(parseInt(req.query.pageSize) || 100, 500)

    if (chatId) {
        verifyChatOwnership(chatId, req.user.email, (err, isOwner) => {
            if (err) return res.status(500).json({ error: err.message })
            if (!isOwner) return res.status(403).json({ error: 'Access denied' })

            const sql = 'SELECT * FROM messages WHERE chatId = ? ORDER BY timestamp DESC LIMIT ?'
            db.all(sql, [chatId, limit], (err, rows) => {
                if (err) return res.status(500).json({ error: err.message })
                res.json({ documents: formatMessages(rows) })
            })
        })
    } else if (req.user.email === ADMIN_EMAIL) {
        const room = req.query.room
        let sql, params
        if (room) {
            sql = 'SELECT * FROM messages WHERE room = ? ORDER BY timestamp DESC LIMIT ?'
            params = [room, limit]
        } else {
            sql = 'SELECT * FROM messages ORDER BY timestamp DESC LIMIT ?'
            params = [limit]
        }
        db.all(sql, params, (err, rows) => {
            if (err) return res.status(500).json({ error: err.message })
            res.json({ documents: formatMessages(rows) })
        })
    } else {
        return res.status(400).json({ error: 'chatId is required' })
    }
}

const sendMessage = (req, res) => {
    const fields = req.body.fields
    if (!fields) return res.status(400).json({ error: 'Invalid data' })

    const id = req.query.documentId || Date.now().toString()
    const text = fields.text?.stringValue || ''
    const isKyle = fields.isKyle?.booleanValue || false
    const timestamp = fields.timestamp?.doubleValue
    const room = fields.room?.stringValue
    const chatId = fields.chatId ? fields.chatId.stringValue : ''
    const imageBase64 = fields.imageBase64 ? fields.imageBase64.stringValue : null

    if (!text && !imageBase64) return res.status(400).json({ error: 'Message cannot be empty' })
    if (text.length > 10000) return res.status(400).json({ error: 'Message too long (max 10,000 chars)' })
    if (imageBase64 && imageBase64.length > 2_800_000) return res.status(400).json({ error: 'Image too large (max ~2MB)' })
    if (!timestamp || !room) return res.status(400).json({ error: 'Missing required fields' })

    const userEmail = req.user.email
    const isAdmin = (userEmail === ADMIN_EMAIL);
    const normalizedUser = userEmail

    if (isKyle && !isAdmin) {
        return res.status(403).json({ error: 'Only admin can send as Kyle' })
    }
    if (!isKyle && room !== normalizedUser) {
        return res.status(403).json({ error: 'Cannot send messages to another user\'s room' })
    }

    const proceed = () => {
        const sql = 'INSERT INTO messages (id, text, isKyle, timestamp, room, imageBase64, chatId) VALUES (?, ?, ?, ?, ?, ?, ?)'

        db.run(sql, [id, text, isKyle ? 1 : 0, timestamp, room, imageBase64, chatId], function (err) {
            if (err) return res.status(500).json({ error: err.message })

            if (isKyle) {
                sendPush(room, 'New message from KyleGPT')
            } else {
                sendPush(ADMIN_EMAIL, `${room}: New message`)
            }

            res.json({ status: 'Message Saved', id })
        })
    }

    if (chatId) {
        verifyChatOwnership(chatId, userEmail, (err, isOwner) => {
            if (err) return res.status(500).json({ error: err.message })
            if (!isOwner) return res.status(403).json({ error: 'Access denied to this chat' })
            proceed()
        })
    } else {
        proceed()
    }
}

const createChat = (req, res) => {
    const userEmail = req.user.email || req.user.phone_number
    const chatId = crypto.randomUUID()
    const createdAt = Date.now() / 1000

    db.run('INSERT INTO chats (chatId, userEmail, title, createdAt, deletedByUser, adminLastReadTimestamp) VALUES (?, ?, \'New Chat\', ?, 0, 0)',
        [chatId, userEmail, createdAt], (err) => {
            if (err) return res.status(500).json({ error: err.message })
            console.log(`New chat created: ${chatId} for ${userEmail}`)
            res.json({ chatId, title: 'New Chat', userEmail, createdAt })
        })
}

const listChats = (req, res) => {
    const userEmail = req.user.email || req.user.phone_number

    const sql = `
        SELECT c.chatId, c.userEmail, c.title, c.createdAt, c.deletedByUser,
               c.userLastReadTimestamp,
               COALESCE(admin_msgs.latestAdminTimestamp, 0) as latestAdminTimestamp
        FROM chats c
        LEFT JOIN messages m ON c.chatId = m.chatId
        LEFT JOIN (
            SELECT chatId, MAX(timestamp) as latestAdminTimestamp
            FROM messages WHERE isKyle = 1
            GROUP BY chatId
        ) admin_msgs ON c.chatId = admin_msgs.chatId
        WHERE c.userEmail = ? AND c.deletedByUser = 0
        GROUP BY c.chatId
        HAVING COUNT(m.id) > 0
        ORDER BY MAX(m.timestamp) DESC
    `
    db.all(sql, [userEmail], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message })
        const chats = (rows || []).map(row => ({
            ...row,
            isUnread: (row.latestAdminTimestamp || 0) > (row.userLastReadTimestamp || 0)
        }))
        res.json({ chats })
    })
}

const softDeleteChat = (req, res) => {
    const { chatId } = req.params

    verifyChatOwnership(chatId, req.user.email || req.user.phone_number, (err, isOwner) => {
        if (err) return res.status(500).json({ error: err.message })
        if (!isOwner) return res.status(403).json({ error: 'Access denied' })

        db.run('UPDATE chats SET deletedByUser = 1 WHERE chatId = ?', [chatId], function (err) {
            if (err) return res.status(500).json({ error: err.message })
            console.log(`Chat soft-deleted: ${chatId}`)
            res.json({ status: 'Deleted' })
        })
    })
}

const userReadChat = (req, res) => {
    const { chatId } = req.params
    const now = Date.now() / 1000

    verifyChatOwnership(chatId, req.user.email || req.user.phone_number, (err, isOwner) => {
        if (err) return res.status(500).json({ error: err.message })
        if (!isOwner) return res.status(403).json({ error: 'Access denied' })

        db.run('UPDATE chats SET userLastReadTimestamp = ? WHERE chatId = ?', [now, chatId], function (err) {
            if (err) return res.status(500).json({ error: err.message })
            res.json({ status: 'User marked as read' })
        })
    })
}

const updateChatTitle = (req, res) => {
    const { chatId } = req.params
    const { title } = req.body
    if (!title || typeof title !== 'string') return res.status(400).json({ error: 'Missing or invalid title' })
    if (title.length > 100) return res.status(400).json({ error: 'Title too long (max 100 chars)' })

    verifyChatOwnership(chatId, req.user.email || req.user.phone_number, (err, isOwner) => {
        if (err) return res.status(500).json({ error: err.message })
        if (!isOwner) return res.status(403).json({ error: 'Access denied' })

        const truncated = truncateTitle(title)
        db.run('UPDATE chats SET title = ? WHERE chatId = ?', [truncated, chatId], function (err) {
            if (err) return res.status(500).json({ error: err.message })
            res.json({ status: 'Title updated', title: truncated })
        })
    })
}

const uploadPublicKey = (req, res) => {
    const { publicKey } = req.body
    const email = req.user.email || req.user.phone_number
    if (!publicKey || typeof publicKey !== 'string') return res.status(400).json({ error: 'Missing publicKey' })
    if (publicKey.length > 200) return res.status(400).json({ error: 'Invalid key format' })

    const now = Date.now() / 1000
    db.run('INSERT OR REPLACE INTO public_keys (email, publicKey, updatedAt) VALUES (?, ?, ?)',
        [email, publicKey, now], (err) => {
            if (err) return res.status(500).json({ error: err.message })
            console.log(`Public key uploaded for: ${email}`)
            res.json({ status: 'Key stored' })
        })
}

const getPublicKey = (req, res) => {
    const targetEmail = req.params.email
    const requesterEmail = req.user.email || req.user.phone_number

    if (requesterEmail !== ADMIN_EMAIL && targetEmail !== ADMIN_EMAIL && requesterEmail !== targetEmail) {
        return res.status(403).json({ error: 'Unauthorized' })
    }

    db.get('SELECT publicKey FROM public_keys WHERE email = ?', [targetEmail], (err, row) => {
        if (err) return res.status(500).json({ error: err.message })
        if (!row) return res.status(404).json({ error: 'No public key found for this user' })
        res.json({ email: targetEmail, publicKey: row.publicKey })
    })
}

module.exports = {
    getMessages,
    sendMessage,
    createChat,
    listChats,
    softDeleteChat,
    userReadChat,
    updateChatTitle,
    uploadPublicKey,
    getPublicKey
}
