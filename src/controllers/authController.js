const admin = require('../config/firebase')
const db = require('../config/database')
const transporter = require('../config/mailer')
require('dotenv').config()

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com';

const requestCode = (req, res) => {
    let { email } = req.body
    if (!email) return res.status(400).json({ error: 'Missing email address' })

    email = email.toLowerCase().trim()

    const code = Math.floor(100000 + Math.random() * 900000).toString()
    const expiresAt = Date.now() + 10 * 60 * 1000

    const sql = 'INSERT OR REPLACE INTO verification_codes (email, code, expiresAt) VALUES (?, ?, ?)'
    db.run(sql, [email, code, expiresAt], async (err) => {
        if (err) return res.status(500).json({ error: err.message })

        if (process.env.SMTP_USER && process.env.SMTP_PASS) {
            try {
                await transporter.sendMail({
                    from: '"KyleGPT" <kylegpt@namgostar.com>',
                    to: email,
                    subject: 'Your KyleGPT Verification Code',
                    html: `
                    <div style="font-family: monospace; max-width: 400px; margin: 0 auto; text-align: center; border: 1px solid #ccc; padding: 20px; border-radius: 12px;">
                        <h2>KyleGPT Login</h2>
                        <p>Your 6-digit verification code is:</p>
                        <h1 style="letter-spacing: 4px; color: #007AFF;">${code}</h1>
                        <p style="color: #666; font-size: 12px;">This code expires in 10 minutes.</p>
                    </div>
                    `
                })
                res.json({ status: 'Code sent' })
            } catch (emailErr) {
                console.error(`Error sending Email to ${email}:`, emailErr.message)
                res.status(500).json({ error: 'Failed to send email. Please check your address or try again later.' })
            }
        } else {
            res.json({ status: 'Code logged to console. SMTP inactive.' })
        }
    })
}

const guestLogin = async (req, res) => {
    try {
        const userRecord = await admin.auth().createUser({})
        const uid = userRecord.uid
        const customToken = await admin.auth().createCustomToken(uid)

        db.run('INSERT OR REPLACE INTO users (email, nickname, uid) VALUES (?, ?, ?)', [uid, null, uid], (err) => {
            if (err) return res.status(500).json({ error: err.message })
            res.json({ customToken, uid })
        })
    } catch (e) {
        res.status(500).json({ error: e.message })
    }
}

const verifyCode = async (req, res) => {
    let { email, code, nickname } = req.body
    if (!email || !code) return res.status(400).json({ error: 'Missing email or code' })

    email = email.toLowerCase().trim()

    db.get('SELECT code, expiresAt FROM verification_codes WHERE email = ?', [email], async (err, row) => {
        if (err) return res.status(500).json({ error: err.message })

        if (!row) return res.status(400).json({ error: 'No code requested for this number' })
        if (Date.now() > row.expiresAt) return res.status(400).json({ error: 'Code expired' })
        if (row.code !== code) return res.status(400).json({ error: 'Invalid code' })

        db.run('DELETE FROM verification_codes WHERE email = ?', [email])

        try {
            let userRecord
            let isNewUser = false
            try {
                userRecord = await admin.auth().getUserByEmail(email)
            } catch (e) {
                if (e.code === 'auth/user-not-found') {
                    userRecord = await admin.auth().createUser({
                        email,
                        emailVerified: true
                    })
                    isNewUser = true
                } else {
                    throw e
                }
            }

            const uid = userRecord.uid

            db.get('SELECT nickname FROM users WHERE uid = ? OR email = ?', [uid, email], async (err, userRow) => {
                try {
                    if (err) return res.status(500).json({ error: err.message })

                    let existingNickname = userRow ? userRow.nickname : null

                    if (!userRow) {
                        db.run('INSERT INTO users (email, nickname, uid) VALUES (?, ?, ?)', [email, null, uid])
                    }

                    if (!existingNickname && userRecord.displayName) {
                        existingNickname = userRecord.displayName
                    }

                    if (nickname) {
                        existingNickname = nickname
                        db.run('UPDATE users SET nickname = ?, uid = ? WHERE email = ?', [nickname, uid, email])
                        await admin.auth().updateUser(uid, { displayName: nickname }).catch(console.error)
                    }

                    const customToken = await admin.auth().createCustomToken(uid)

                    res.json({
                        customToken,
                        email,
                        uid,
                        nickname: existingNickname,
                        isNewUser: Boolean(isNewUser || !existingNickname)
                    })
                } catch (innerErr) {
                    res.status(500).json({ error: innerErr.message })
                }
            })
        } catch (error) {
            res.status(500).json({ error: error.message })
        }
    })
}

const registerDevice = (req, res) => {
    const { token } = req.body
    const email = req.user.email || req.user.phone_number
    if (!token) return res.status(400).json({ error: 'Missing device token' })

    const sql = 'INSERT OR REPLACE INTO device_tokens (email, token) VALUES (?, ?)'
    db.run(sql, [email, token], (err) => {
        if (err) return res.status(500).json({ error: err.message })
        res.json({ status: 'Registered' })
    })
}

const updateNickname = async (req, res) => {
    const { nickname } = req.body
    if (!nickname) return res.status(400).json({ error: 'Nickname is required' })

    const userEmail = req.user.email
    if (!userEmail) return res.status(400).json({ error: 'No user email found on auth token' })

    const uid = req.user.uid

    db.run('INSERT OR REPLACE INTO users (email, nickname, uid) VALUES (?, ?, ?)', [userEmail, nickname, uid], async (err) => {
        if (err) return res.status(500).json({ error: err.message })

        try {
            await admin.auth().updateUser(uid, { displayName: nickname })
            res.json({ status: 'Nickname updated' })
        } catch (fbErr) {
            res.json({ status: 'Nickname updated locally, Firebase sync failed' })
        }
    })
}

const deleteAccount = (req, res) => {
    const email = req.user.email
    const uid = req.user.uid

    db.run('DELETE FROM messages WHERE room = ?', [email], (err) => {
        if (err) console.error('Error deleting messages:', err)

        db.run('DELETE FROM chats WHERE userEmail = ?', [email], (err) => {
            if (err) console.error('Error deleting chats:', err)

            db.run('DELETE FROM device_tokens WHERE email = ?', [email], (err) => {
                if (err) console.error('Error deleting device token:', err)

                db.run('DELETE FROM public_keys WHERE email = ?', [email], (err) => {
                    if (err) console.error('Error deleting public key:', err)

                    admin.auth().deleteUser(uid)
                        .then(() => res.json({ status: 'Account deleted' }))
                        .catch(() => res.json({ status: 'Local data deleted, Firebase cleanup may be needed' }))
                })
            })
        })
    })
}

module.exports = {
    requestCode,
    guestLogin,
    verifyCode,
    registerDevice,
    updateNickname,
    deleteAccount
}
