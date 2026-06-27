import React from 'react';
import {View, Text, StyleSheet, TouchableOpacity, ScrollView} from 'react-native';
import {Drawer} from 'expo-router/drawer';
import {DrawerContentScrollView, DrawerItemList} from 'expo-router/drawer';
import {Ionicons} from '@expo/vector-icons';

import {Picker} from '@react-native-picker/picker';
import {router, useRouter} from 'expo-router';
import {useGroups} from "@/context/groupContext";
import {useAuth} from "@/context/authContext";
import {useTheme} from "@/context/themeContext";
import CustomDropdown from "@/components/CustomDropdown";
import {GroceryGroup} from "@/types/models";

function CustomDrawerContent(props: any) {
    const {isLoggedIn, userProfile, pendingInvites, refreshSocialData} = useAuth();
    const {groups, activeGroupId, changeActiveGroup} = useGroups();
    const {colors} = useTheme();
    const router = useRouter();

    const currentRoute = props.state.routes[props.state.index]?.name;

    const handleGroupSelection = () => {

    }

    return (
        <View style={{flex: 1, backgroundColor: colors.card}}>
            <ScrollView
                {...props}
                contentContainerStyle={{flexGrow: 1, paddingTop: 0}}
                bounces={false}
            >
                {/* Header block uses global brand primary or adapts to theme state */}
                <View style={[styles.drawerHeader, {backgroundColor: colors.primary}]}>
                    <Ionicons name="cart" size={42} color="white"/>
                    <Text style={styles.drawerTitle}>Grocery Master</Text>
                    {isLoggedIn && <Text style={styles.drawerSubtitle}>{userProfile?.email}</Text>}
                </View>

                <TouchableOpacity
                    style={[
                        styles.manualTile,
                        currentRoute === 'home' && {backgroundColor: `${colors.primary}15`} // 15% opacity primary accent background if active
                    ]}
                    onPress={() => router.navigate('/drawer/home')}
                >
                    <Ionicons
                        name="speedometer-outline"
                        size={22}
                        color={currentRoute === 'home' ? colors.primary : colors.subtext}
                    />
                    <Text style={[
                        styles.manualTileText,
                        {
                            color: currentRoute === 'home' ? colors.primary : colors.text,
                            fontWeight: currentRoute === 'home' ? '600' : '400'
                        }
                    ]}>
                        Dashboard
                    </Text>
                </TouchableOpacity>

                <View style={[styles.sectionDivider, {backgroundColor: colors.border}]}/>
                <View style={{zIndex: 5000, overflow: 'visible'}}>
                    <Text style={[styles.sectionLabel, {color: colors.subtext}]}>Active Group</Text>

                    {/* 2. Place Custom Dropdown inside its own container with high zIndex and visible overflow */}
                    <View style={styles.dropdownWrapper}>
                        <CustomDropdown<GroceryGroup>
                            data={groups}
                            placeholder="Choose a group..."
                            colors={colors}
                            onSelect={(group) => {
                                changeActiveGroup(group.id);
                                router.replace({
                                    pathname: '/drawer/list_selection',
                                    params: {groupId: group.id, refreshKey: Date.now().toString()}
                                });
                            }}
                            getLabel={(item) => item.name}
                            getValue={(item) => item.id}
                            renderCustomItem={(item) => (
                                <View style={styles.customRow}>
                                    <Text style={[styles.itemName, {color: colors.text}]}>{item.name}</Text>
                                    {item.isShared && (
                                        <View style={styles.badge}>
                                            <Text style={styles.badgeText}>Shared</Text>
                                        </View>
                                    )}
                                </View>
                            )}
                        />
                    </View>
                </View>

                {/* Secondary list navigation items */}
                <TouchableOpacity
                    style={styles.drawerTile}
                    onPress={() => {
                        refreshSocialData();
                        router.push('/modals/invitations');
                    }}
                >
                    <Ionicons name="mail-outline" size={22} color="orange"/>
                    <Text style={[styles.tileText, {color: colors.text}]}>Received Invitations</Text>
                    {pendingInvites.length > 0 && (
                        <View style={styles.badge}>
                            <Text style={styles.badgeText}>{pendingInvites.length}</Text>
                        </View>
                    )}
                </TouchableOpacity>
                <TouchableOpacity
                    style={[
                        styles.manualTile,
                        currentRoute === 'settings' && {backgroundColor: `${colors.primary}15`} // 15% opacity primary accent background if active
                    ]}
                    onPress={() => router.navigate('/drawer/settings')}
                >
                    <Ionicons
                        name="cog"
                        size={22}
                        color={currentRoute === 'settings' ? colors.primary : colors.subtext}
                    />
                    <Text style={[
                        styles.manualTileText,
                        {
                            color: currentRoute === 'settings' ? colors.primary : colors.text,
                            fontWeight: currentRoute === 'settings' ? '600' : '400'
                        }
                    ]}>
                        Settings
                    </Text>
                </TouchableOpacity>
            </ScrollView>
        </View>
    );
}

export default function DrawerLayout() {
    const {groups, activeGroupId, handleShareAction} = useGroups();
    const {colors} = useTheme(); // 👈 Consume context color palette for headers
    const {isLoggedIn, userProfile, pendingInvites, refreshSocialData} = useAuth();
    const activeGroup = groups.find(g => g.id === activeGroupId) || {id: '', name: 'None', isShared: false};

    return (
        <Drawer
            drawerContent={(props) => <CustomDrawerContent {...props} />}
            screenOptions={{
                headerStyle: {backgroundColor: colors.primary}, // Dynamically switch native header tint profile
                headerTintColor: colors.text,
                drawerStyle: {backgroundColor: colors.card},
                drawerActiveTintColor: colors.primary,
                drawerInactiveTintColor: colors.subtext,
            }}
        >
            <Drawer.Screen
                name="home"
                options={{
                    title: 'Dashboard',
                }}
            />

            {/* List Selection: Explicitly contains the share action icon */}
            <Drawer.Screen
                name="list_selection"
                options={{
                    title: activeGroup.id ? activeGroup.name : 'Select List',
                    headerRight: () => (
                        activeGroup.id ? (
                            <TouchableOpacity
                                onPress={() => {
                                    refreshSocialData();
                                    router.push('/modals/send_invite');
                                }}
                                style={{marginRight: 16}}
                            >
                                <Ionicons
                                    name="person-add"
                                    size={24}
                                    color={colors.text}
                                />
                            </TouchableOpacity>
                        ) : null
                    )
                }}
            />
        </Drawer>
    );
}

const styles = StyleSheet.create({
    drawerHeader: {
        padding: 20,
        paddingTop: 40,
        marginBottom: 10,
    },
    drawerTitle: {
        color: 'white',
        fontSize: 22,
        fontWeight: 'bold',
        marginTop: 8,
    },
    dropdownWrapper: {
        marginHorizontal: 16,
        marginBottom: 16,
        position: 'relative',
        zIndex: 9999,          // Forces layout layer depth on iOS
        elevation: 9999,       // Forces layout layer depth on Android
        overflow: 'visible',   // Prevents parent container cropping
    },
    customRow: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
    },
    itemName: {
        fontSize: 16,
        color: '#333',
    },
    drawerSubtitle: {
        color: 'rgba(255,255,255,0.7)',
        fontSize: 12,
        marginTop: 4,
    },
    sectionDivider: {
        height: 1,
        marginVertical: 10,
    },
    sectionLabel: {
        paddingHorizontal: 18,
        fontSize: 12,
        fontWeight: 'bold',
        marginBottom: 4,
    },
    pickerContainer: {
        marginHorizontal: 16,
        borderWidth: 1,
        borderRadius: 8,
        marginBottom: 10,
        overflow: 'hidden',
    },
    drawerTile: {
        flexDirection: 'row',
        alignItems: 'center',
        padding: 16,
        paddingHorizontal: 18,
    },
    tileText: {
        fontSize: 14,
        marginLeft: 32,
        flex: 1,
    },
    badge: {
        backgroundColor: 'red',
        borderRadius: 10,
        minWidth: 20,
        height: 20,
        justifyContent: 'center',
        alignItems: 'center',
        paddingHorizontal: 4,
    },
    badgeText: {
        color: 'white',
        fontSize: 11,
        fontWeight: 'bold',
    },
    manualTile: {
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 12,
        paddingHorizontal: 16,
        marginHorizontal: 8,
        marginVertical: 2,
        borderRadius: 8,
    },
    manualTileText: {
        fontSize: 15,
        marginLeft: 32,
    },
});