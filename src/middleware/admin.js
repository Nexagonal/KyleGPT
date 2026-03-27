require('dotenv').config()

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com';

function adminOnly(req, res, next) {
    if (req.user.email !== ADMIN_EMAIL) {
        return res.status(403).json({ error: 'Forbidden: admin access required' });
    }
    next();
}

module.exports = adminOnly
