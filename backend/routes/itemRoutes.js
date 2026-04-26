const express = require('express');
const router = express.Router();
const itemCtrl = require('../controllers/itemController');

router.post('/', itemCtrl.createItem);
router.put('/update', itemCtrl.updateItem);
router.post('/sync', itemCtrl.syncItems);
module.exports = router;