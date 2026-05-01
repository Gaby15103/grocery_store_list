const { DataTypes, Op} = require('sequelize');
const sequelize = require('../config/db');

const User = sequelize.define('User', {
    id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
    email: { type: DataTypes.STRING, unique: true, allowNull: false },
    firstName: { type: DataTypes.STRING, allowNull: false },
    lastName: { type: DataTypes.STRING, allowNull: false },
    passwordHash: DataTypes.STRING,
    authorizedDevices: {
        type: DataTypes.JSONB,
        defaultValue: [],
        allowNull: false
    }
});

const Group = sequelize.define('Group', {
    id: { type: DataTypes.STRING, primaryKey: true },
    name: { type: DataTypes.STRING, allowNull: false },
    ownerId: DataTypes.UUID
});

const UserGroup = sequelize.define('UserGroup', {
    role: { type: DataTypes.STRING, defaultValue: 'member' },
    status: { type: DataTypes.STRING, defaultValue: 'pending' }
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
    note: {
        type: DataTypes.TEXT,
        allowNull: true
    },
    imagePath: {
        type: DataTypes.STRING,
        allowNull: true
    },
});



// Relationships
Group.hasMany(List, { onDelete: 'CASCADE', foreignKey: 'GroupId' });
List.belongsTo(Group, { foreignKey: 'GroupId' });

List.hasMany(Item, { onDelete: 'CASCADE', foreignKey: 'ListId' });
Item.belongsTo(List, { foreignKey: 'ListId' });

User.belongsToMany(Group, { through: UserGroup });
Group.belongsToMany(User, { through: UserGroup, onDelete: 'CASCADE' });

UserGroup.belongsTo(User);
UserGroup.belongsTo(Group, { onDelete: 'CASCADE', foreignKey: 'GroupId' });
Group.hasMany(UserGroup, { onDelete: 'CASCADE', foreignKey: 'GroupId' });

module.exports = { Group, List, Item, User, UserGroup, sequelize, Op };