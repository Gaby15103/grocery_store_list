const express = require('express');
const router = express.Router();
const userCtrl = require('../controllers/userController');

router.post('/register', userCtrl.register);
router.get('/invitations', userCtrl.getInvitations);
router.put('/profile', userCtrl.updateProfile);
router.post('/link', userCtrl.linkAccount);
router.get('/contacts', userCtrl.getContacts);
module.exports = router;