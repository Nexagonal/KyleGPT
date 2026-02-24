const express = require('express')
const bodyParser = require('body-parser')
const cors = require('cors')
const helmet = require('helmet')
const rateLimit = require('express-rate-limit')
const path = require('path')
require('dotenv').config()

require('events').EventEmitter.defaultMaxListeners = 50

const app = express()
const port = process.env.PORT || 3000

app.use(express.static(path.join(__dirname, '../public')))
app.get('/terms', (req, res) => res.sendFile(path.join(__dirname, '../public', 'terms.html')))
app.get('/privacy', (req, res) => res.sendFile(path.join(__dirname, '../public', 'privacy.html')))

app.set('trust proxy', 1)
app.use(helmet())
app.use(cors({ origin: false }))
app.use(bodyParser.json({ limit: '5mb' }))

const generalLimiter = rateLimit({ windowMs: 60000, max: 10000, message: { error: 'Too many requests' } })
app.use(generalLimiter)

app.get('/health', (req, res) => res.status(200).send('OK'))

const authRoutes = require('./routes/authRoutes')
const chatRoutes = require('./routes/chatRoutes')
const adminRoutes = require('./routes/adminRoutes')

app.use('/', authRoutes)
app.use('/', chatRoutes)
app.use('/', adminRoutes)

app.listen(port, () => {
    console.log(`KyleGPT Server running on http://localhost:${port}`)
    console.log('Push Environment: PRODUCTION')
    console.log('Auth: Firebase Admin SDK')
})
