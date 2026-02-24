const express = require('express')
const router = express.Router()
const authController = require('../controllers/authController')
const authMiddleware = require('../middleware/auth')

router.post('/auth/request-code', authController.requestCode)
router.post('/auth/guest', authController.guestLogin)
router.post('/auth/verify-code', authController.verifyCode)
router.post('/register-device', authMiddleware, authController.registerDevice)
router.post('/user/nickname', authMiddleware, authController.updateNickname)
router.delete('/account', authMiddleware, authController.deleteAccount)

module.exports = router
