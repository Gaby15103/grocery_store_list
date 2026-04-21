const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Group = sequelize.define('Group', {
    id: { type: DataTypes.STRING, primaryKey: true },
    name: { type: DataTypes.STRING, allowNull: false },
});

const List = sequelize.define('List', {
    id: { type: DataTypes.STRING, primaryKey: true },
    name: { type: DataTypes.STRING, allowNull: false },
    isArchived: { type: DataTypes.BOOLEAN, defaultValue: false },
});

const Item = sequelize.define('Item', {
    name: { type: DataTypes.STRING, allowNull: false },
    status: {
        type: DataTypes.ENUM('pending', 'bought', 'discarded'),
        defaultValue: 'pending'
    },
});

// Relationships
Group.hasMany(List);
List.belongsTo(Group);
List.hasMany(Item);
Item.belongsTo(List);

module.exports = { Group, List, Item, sequelize };