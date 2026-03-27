const admin = require('firebase-admin')
require('dotenv').config()

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT || './serviceAccountKey.json'
try {
    admin.initializeApp({
        credential: admin.credential.cert(require('../../' + serviceAccountPath.replace('./', '')))
    })
    console.log('Firebase Admin initialized.')
} catch (e) {
    console.error('Firebase Admin init failed. Auth will reject all requests:', e.message)
    console.error('   Download your service account key from Firebase Console -> Project Settings -> Service Accounts')
}

module.exports = admin
