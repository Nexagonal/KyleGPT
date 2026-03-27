const sqlite3 = require('sqlite3').verbose()
const crypto = require('crypto')
const path = require('path')
const { truncateTitle } = require('../utils/formatters')
require('dotenv').config()

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com';
const dbPath = path.join(__dirname, '../../chat.db')

const db = new sqlite3.Database(dbPath, (err) => {
    if (err) console.error(err.message)
    console.log('Connected to SQLite database.')
})

db.serialize(() => {
    db.run('CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY, text TEXT, isKyle INTEGER, timestamp REAL, room TEXT, imageBase64 TEXT)')
    db.run('CREATE TABLE IF NOT EXISTS status (room TEXT PRIMARY KEY, lastActive REAL)')
    db.run('CREATE TABLE IF NOT EXISTS device_tokens (email TEXT PRIMARY KEY, token TEXT)')
    db.run('CREATE TABLE IF NOT EXISTS public_keys (email TEXT PRIMARY KEY, publicKey TEXT NOT NULL, updatedAt REAL NOT NULL)')

    db.get("SELECT name FROM sqlite_master WHERE type='table' AND name='verification_codes'", (err, row) => {
        if (row) {
            db.all('PRAGMA table_info(verification_codes)', (err, columns) => {
                if (!err && columns && columns.some(col => col.name === 'phone')) {
                    console.log('Migrating: Dropping old phone-based auth tables...')
                    db.serialize(() => {
                        db.run('DROP TABLE IF EXISTS users')
                        db.run('DROP TABLE IF EXISTS verification_codes')
                        createAuthTables()
                    })
                } else {
                    createAuthTables()
                }
            })
        } else {
            createAuthTables()
        }
    })

    function createAuthTables() {
        db.serialize(() => {
            db.run(`CREATE TABLE IF NOT EXISTS users (
                email TEXT PRIMARY KEY,
                nickname TEXT,
                uid TEXT
            )`)
            db.run(`CREATE TABLE IF NOT EXISTS verification_codes (
                email TEXT PRIMARY KEY,
                code TEXT,
                expiresAt REAL
            )`)
        })
    }

    db.run(`CREATE TABLE IF NOT EXISTS chats (
        chatId TEXT PRIMARY KEY,
        userEmail TEXT NOT NULL,
        title TEXT DEFAULT 'New Chat',
        createdAt REAL NOT NULL,
        deletedByUser INTEGER DEFAULT 0,
        adminLastReadTimestamp REAL DEFAULT 0
    )`)

    db.all('PRAGMA table_info(messages)', (err, columns) => {
        if (err) { console.error('Migration check error:', err); return }

        const hasChatId = columns.some(col => col.name === 'chatId')
        if (!hasChatId) {
            console.log('Migrating: Adding chatId column to messages...')
            db.run('ALTER TABLE messages ADD COLUMN chatId TEXT DEFAULT \'\'', (err) => {
                if (err) { console.error('Migration error:', err); return }
                console.log('chatId column added. Backfilling existing messages...')
                migrateExistingMessages()
            })
        } else {
            console.log('chatId column already exists.')
        }
    })

    setTimeout(() => {
        db.run(`DELETE FROM chats WHERE chatId IN (
            SELECT c.chatId FROM chats c
            LEFT JOIN messages m ON c.chatId = m.chatId
            WHERE m.id IS NULL AND c.title = 'New Chat'
        )`, (err) => {
            if (err) console.error('Cleanup error:', err)
            else console.log('Cleaned up empty chats.')
        })
    }, 3000)

    db.all('PRAGMA table_info(chats)', (err, columns) => {
        if (err) { console.error('Chats migration check error:', err); return }
        const hasUserLastRead = columns.some(col => col.name === 'userLastReadTimestamp')
        if (!hasUserLastRead) {
            console.log('Migrating: Adding userLastReadTimestamp column to chats...')
            db.run('ALTER TABLE chats ADD COLUMN userLastReadTimestamp REAL DEFAULT 0', (err) => {
                if (err) console.error('Migration error:', err)
                else console.log('userLastReadTimestamp column added.')
            })
        }
    })
})

function migrateExistingMessages() {
    db.all('SELECT DISTINCT room FROM messages WHERE chatId = \'\' OR chatId IS NULL', (err, rooms) => {
        if (err) { console.error('Migration query error:', err); return }
        if (!rooms || rooms.length === 0) { console.log('No messages to migrate.'); return }

        rooms.forEach(({ room }) => {
            if (!room || room === ADMIN_EMAIL) return

            const chatId = crypto.randomUUID()
            const now = Date.now() / 1000

            db.get('SELECT text FROM messages WHERE room = ? AND isKyle = 0 AND (chatId = \'\' OR chatId IS NULL) ORDER BY timestamp ASC LIMIT 1', [room], (err, row) => {
                const title = row && row.text ? truncateTitle(row.text) : 'Legacy Chat'

                db.run('INSERT INTO chats (chatId, userEmail, title, createdAt, deletedByUser, adminLastReadTimestamp) VALUES (?, ?, ?, ?, 0, 0)',
                    [chatId, room, title, now], (err) => {
                        if (err) { console.error(`Migration error for ${room}:`, err); return }

                        db.run('UPDATE messages SET chatId = ? WHERE room = ? AND (chatId = \'\' OR chatId IS NULL)',
                            [chatId, room], (err) => {
                                if (err) console.error(`Backfill error for ${room}:`, err)
                                else console.log(`Migrated ${room} -> chatId: ${chatId}`)
                            })
                    })
            })
        })
    })
}

module.exports = db
