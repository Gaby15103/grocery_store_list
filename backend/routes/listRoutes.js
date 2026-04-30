const express = require('express');
const router = express.Router();
const itemCtrl = require('../controllers/itemController');

router.post('/', itemCtrl.createList);
router.delete('/:listId', itemCtrl.deleteList);
router.get('/:listId/items', itemCtrl.getListItems);

module.exports = router;