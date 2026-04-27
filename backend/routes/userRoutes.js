const express = require('express');
const router = express.Router();
const userCtrl = require('../controllers/userController');

router.post('/register', userCtrl.register);
router.get('/invitations', userCtrl.getInvitations);
router.put('/profile', userCtrl.updateProfile);
router.post('/link', userCtrl.linkAccount);
router.get('/contacts', userCtrl.getContacts);
router.get('/me', userCtrl.getUser);
router.get('/profile/:email', userCtrl.getUserProfile);
module.exports = router;