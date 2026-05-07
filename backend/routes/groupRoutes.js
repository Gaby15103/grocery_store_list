const express = require('express');
const router = express.Router();
const groupCtrl = require('../controllers/groupController');
const itemCtrl = require('../controllers/itemController');

router.get('/', groupCtrl.getGroups);
router.post('/', groupCtrl.createGroup);
router.get('/:groupId', groupCtrl.getGroup);
router.delete('/:groupId', groupCtrl.deleteGroup);
router.get('/:groupId/lists', itemCtrl.getListsByGroup);
router.get('/:groupId/make-public', groupCtrl.makePublic);
router.post('/:groupId/invite', groupCtrl.inviteUser);
router.put('/:groupId/invite/respond', groupCtrl.respondToInvite);
module.exports = router;