const admin = require('../config/firebase')

async function authMiddleware(req, res, next) {
    const authHeader = req.headers.authorization
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Missing or invalid Authorization header' })
    }

    const idToken = authHeader.replace('Bearer ', '')
    try {
        const decoded = await admin.auth().verifyIdToken(idToken)
        req.user = {
            uid: decoded.uid,
            email: decoded.email?.toLowerCase() || decoded.uid,
            phone_number: decoded.phone_number,
            emailVerified: decoded.email_verified || false
        }
        next()
    } catch (e) {
        return res.status(401).json({ error: 'Invalid or expired token' })
    }
}

module.exports = authMiddleware
