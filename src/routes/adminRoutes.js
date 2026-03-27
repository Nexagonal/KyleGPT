const express = require('express')
const router = express.Router()
const adminController = require('../controllers/adminController')
const authMiddleware = require('../middleware/auth')
const adminOnly = require('../middleware/admin')

router.use(authMiddleware)

router.get('/chats/all', adminOnly, adminController.listAllChats)
router.get('/export', adminOnly, adminController.exportMessages)
router.patch('/status', adminOnly, adminController.updateStatus)
router.get('/status', adminController.getStatus)
router.patch('/chats/:chatId/read', adminOnly, adminController.adminReadChat)

module.exports = router
