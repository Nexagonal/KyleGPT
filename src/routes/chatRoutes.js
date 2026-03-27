const express = require('express')
const router = express.Router()
const chatController = require('../controllers/chatController')
const authMiddleware = require('../middleware/auth')
const rateLimit = require('express-rate-limit')

const messageLimiter = rateLimit({ windowMs: 60000, max: 1000, message: { error: 'Too many messages' } })

router.use(authMiddleware)

router.get('/messages', chatController.getMessages)
router.post('/messages', messageLimiter, chatController.sendMessage)
router.post('/chats', chatController.createChat)
router.get('/chats', chatController.listChats)
router.patch('/chats/:chatId/delete', chatController.softDeleteChat)
router.patch('/chats/:chatId/user-read', chatController.userReadChat)
router.patch('/chats/:chatId/title', chatController.updateChatTitle)
router.put('/keys', chatController.uploadPublicKey)
router.get('/keys/:email', chatController.getPublicKey)

module.exports = router
