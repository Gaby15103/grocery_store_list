import React, {createContext, useCallback, useContext, useEffect, useState} from 'react';
import {
    View, Text, StyleSheet, TouchableOpacity, ScrollView, Modal, FlatList, Keyboard, Platform,
    TouchableWithoutFeedback, KeyboardAvoidingView, TextInput, Switch
} from 'react-native';
import {Drawer} from 'expo-router/drawer';
import {Ionicons} from '@expo/vector-icons';

import {useRouter} from 'expo-router';
import {useGroups} from "@/context/groupContext";
import {useAuth} from "@/context/authContext";
import {useTheme} from "@/context/themeContext";
import CustomDropdown from "@/components/CustomDropdown";
import {GroceryGroup, GroceryItem} from "@/types/models";
import {ActivityIndicator, Divider} from "react-native-paper";
import {useSocket, useSocketEvent} from "@/context/socketContext";

interface LayoutContextType {
    openInvitationModal: () => void;
}

const LayoutContext = createContext<LayoutContextType | null>(null);

function CustomDrawerContent(props: any) {
    const [processingId, setProcessingId] = useState<string | null>(null);
    const {loadGroups} = useGroups();
    const {isLoggedIn, userProfile, pendingInvites, refreshSocialData, respondToInvitation} = useAuth();
    const {groups, activeGroupId, changeActiveGroup, createGroup, makeGroupPublic} = useGroups();
    const {colors} = useTheme();
    const router = useRouter();

    const [newGroupModalVisible, setNewGroupModalVisible] = useState(false);
    const [newGroupName, setNewGroupName] = useState('');
    const [isGroupShared, setIsGroupShared] = useState(false);
    const [isCreating, setIsCreating] = useState(false);

    const currentRoute = props.state.routes[props.state.index]?.name;

    const handleResponse = async (groupId: string, status: 'accepted' | 'declined') => {
        setProcessingId(groupId);
        try {
            await respondToInvitation(groupId, status);
            if (status === 'accepted') {
                await loadGroups();
            }
        } catch (error) {
            console.error(error);
        } finally {
            setProcessingId(null);
        }
    };

    const handleCreateGroupSubmit = async () => {
        if (!newGroupName.trim()) return;
        setIsCreating(true);
        try {
            let group_id = await createGroup(newGroupName.trim());

            setNewGroupName('');
            setIsGroupShared(false);
            setNewGroupModalVisible(false);
        } catch (error) {
            console.error("Erreur lors de la création du groupe:", error);
        } finally {
            setIsCreating(false);
        }
    };

    return (
        <View style={{flex: 1, backgroundColor: colors.card}}>
            <ScrollView
                {...props}
                contentContainerStyle={{flexGrow: 1, paddingTop: 0}}
                bounces={false}
            >
                {/* En-tête du Drawer */}
                <View style={[styles.drawerHeader, {backgroundColor: colors.primary}]}>
                    <Ionicons name="cart" size={42} color="white"/>
                    <Text style={styles.drawerTitle}>Grocery Master</Text>
                    {isLoggedIn && <Text style={styles.drawerSubtitle}>{userProfile?.email}</Text>}
                </View>

                {/* Tuile Tableau de bord */}
                <TouchableOpacity
                    style={[
                        styles.manualTile,
                        currentRoute === 'home' && {backgroundColor: `${colors.primary}15`}
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
                        Tableau de bord
                    </Text>
                </TouchableOpacity>

                <View style={[styles.sectionDivider, {backgroundColor: colors.border}]}/>

                {/* Section Groupe Actif */}
                <View style={{zIndex: 5000, overflow: 'visible'}}>
                    <Text style={[styles.sectionLabel, {color: colors.subtext}]}>Groupe Actif</Text>
                    <View style={styles.dropdownWrapper}>
                        <CustomDropdown<GroceryGroup>
                            data={groups}
                            placeholder="Choisir un groupe..."
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
                                            <Text style={styles.badgeText}>Partagé</Text>
                                        </View>
                                    )}
                                </View>
                            )}
                        />
                    </View>
                </View>

                {/* Bouton Ajouter un Groupe */}
                <TouchableOpacity
                    style={styles.drawerTile}
                    onPress={() => setNewGroupModalVisible(true)}
                >
                    <Ionicons name="add-circle-outline" size={22} color={colors.primary}/>
                    <Text style={[styles.tileText, {color: colors.text}]}>Créer un groupe</Text>
                </TouchableOpacity>

                {/* Tuile Invitations Reçues */}
                <TouchableOpacity
                    style={styles.drawerTile}
                    onPress={() => {
                        refreshSocialData();
                        props.setInvitationModalVisible(true);
                    }}
                >
                    <Ionicons name="mail-outline" size={22} color="orange"/>
                    <Text style={[styles.tileText, {color: colors.text}]}>Invitations reçues</Text>
                    {pendingInvites.length > 0 && (
                        <View style={[styles.badge, {backgroundColor: colors.primary || 'orange'}]}>
                            <Text style={styles.badgeText}>{pendingInvites.length}</Text>
                        </View>
                    )}
                </TouchableOpacity>

                {/* Modal : Créer un Nouveau Groupe */}
                <Modal
                    visible={newGroupModalVisible}
                    animationType='fade'
                    transparent
                    onRequestClose={() => setNewGroupModalVisible(false)}
                >
                    <TouchableOpacity
                        style={styles.modalOverlay}
                        activeOpacity={1}
                        onPress={() => setNewGroupModalVisible(false)}
                    >
                        <TouchableWithoutFeedback onPress={Keyboard.dismiss}>
                            <KeyboardAvoidingView
                                behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
                                style={{width: '100%', alignItems: 'center'}}
                            >
                                <TouchableOpacity
                                    activeOpacity={1}
                                    style={[styles.dialogCard, {
                                        backgroundColor: colors.card,
                                        borderColor: colors.border
                                    }]}
                                >
                                    <View style={styles.modalHeader}>
                                        <Text style={[styles.modalHeaderTitle, {color: colors.text}]}>Nouveau groupe</Text>
                                        <TouchableOpacity onPress={() => setNewGroupModalVisible(false)}>
                                            <Ionicons name="close" size={24} color={colors.subtext}/>
                                        </TouchableOpacity>
                                    </View>

                                    <Text style={[styles.inputLabel, {color: colors.text}]}>Nom du groupe</Text>
                                    <TextInput
                                        style={[styles.textInput, {color: colors.text, borderColor: colors.border, backgroundColor: colors.inputBg || 'rgba(255,255,255,0.05)'}]}
                                        placeholder="Ex: Maison, Chalet..."
                                        placeholderTextColor={colors.subtext}
                                        value={newGroupName}
                                        onChangeText={setNewGroupName}
                                    />

                                    <View style={styles.switchContainer}>
                                        <View style={{flex: 1, paddingRight: 8}}>
                                            <Text style={[styles.switchLabel, {color: colors.text}]}>Groupe public / partagé</Text>
                                            <Text style={{color: colors.subtext, fontSize: 12}}>Permet d'inviter d'autres membres à voir la liste.</Text>
                                        </View>
                                        <Switch
                                            value={isGroupShared}
                                            onValueChange={setIsGroupShared}
                                            trackColor={{ false: "#767577", true: colors.primary }}
                                        />
                                    </View>

                                    <TouchableOpacity
                                        style={[styles.submitButton, {backgroundColor: colors.primary}]}
                                        onPress={handleCreateGroupSubmit}
                                        disabled={isCreating || !newGroupName.trim()}
                                    >
                                        {isCreating ? (
                                            <ActivityIndicator size="small" color="white" />
                                        ) : (
                                            <Text style={styles.submitButtonText}>Créer le groupe</Text>
                                        )}
                                    </TouchableOpacity>
                                </TouchableOpacity>
                            </KeyboardAvoidingView>
                        </TouchableWithoutFeedback>
                    </TouchableOpacity>
                </Modal>

                {/* Modal : Invitations Reçues */}
                <Modal
                    visible={props.invitationModalVisible}
                    animationType='fade'
                    transparent
                    onRequestClose={() => props.setInvitationModalVisible(false)}
                >
                    <TouchableOpacity
                        style={styles.modalOverlay}
                        activeOpacity={1}
                        onPress={() => props.setInvitationModalVisible(false)}
                    >
                        <TouchableWithoutFeedback onPress={Keyboard.dismiss}>
                            <KeyboardAvoidingView
                                behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
                                style={{width: '100%', alignItems: 'center'}}
                            >
                                <TouchableOpacity
                                    activeOpacity={1}
                                    style={[styles.dialogCard, {
                                        backgroundColor: colors.card,
                                        borderColor: colors.border
                                    }]}
                                >
                                    <View style={styles.modalHeader}>
                                        <Text style={[styles.modalHeaderTitle, {color: colors.text}]}>Invitations</Text>
                                        <TouchableOpacity onPress={() => props.setInvitationModalVisible(false)}>
                                            <Ionicons name="close" size={24} color={colors.subtext}/>
                                        </TouchableOpacity>
                                    </View>

                                    {pendingInvites.length === 0 ? (
                                        <View style={styles.centeredEmptyState}>
                                            <View style={[styles.iconCircle, {backgroundColor: `${colors.text}10`}]}>
                                                <Ionicons name="mail-open-outline" size={32} color="orange"/>
                                            </View>
                                            <Text style={[styles.emptyText, {color: colors.text}]}>Aucune invitation en attente</Text>
                                            <Text style={{
                                                color: colors.subtext,
                                                fontSize: 13,
                                                textAlign: 'center',
                                                marginTop: 4
                                            }}>
                                                Quand quelqu'un vous invite à rejoindre une liste, elle apparaîtra ici.
                                            </Text>
                                        </View>
                                    ) : (
                                        <FlatList
                                            data={pendingInvites}
                                            keyExtractor={(item) => item.groupId}
                                            ItemSeparatorComponent={() => <View style={{height: 12}}/>}
                                            style={{maxHeight: 400}}
                                            showsVerticalScrollIndicator={false}
                                            renderItem={({item}) => (
                                                <View style={[styles.inviteCard, {
                                                    backgroundColor: colors.inputBg || '#1e1e1e',
                                                    borderColor: colors.border
                                                }]}>
                                                    <View style={[styles.cardAccentStrip, {backgroundColor: colors.primary}]}/>

                                                    <View style={styles.inviteCardContent}>
                                                        <View style={{flex: 1, marginRight: 8}}>
                                                            <Text style={[styles.inviteGroupName, {color: colors.text}]} numberOfLines={1}>
                                                                {item.GroupName ?? 'Groupe sans nom'}
                                                            </Text>
                                                            <Text style={[styles.inviteOwner, {color: colors.subtext}]} numberOfLines={1}>
                                                                De : {item.OwnerEmail}
                                                            </Text>
                                                        </View>

                                                        <View style={styles.inviteActionContainer}>
                                                            {processingId === item.groupId ? (
                                                                <ActivityIndicator size="small" color={colors.primary} style={{marginRight: 12}}/>
                                                            ) : (
                                                                <>
                                                                    <TouchableOpacity
                                                                        onPress={() => handleResponse(item.groupId, 'accepted')}
                                                                        style={[styles.actionPillButton, styles.acceptPill]}
                                                                    >
                                                                        <Ionicons name="checkmark" size={18} color="white"/>
                                                                    </TouchableOpacity>
                                                                    <TouchableOpacity
                                                                        onPress={() => handleResponse(item.groupId, 'declined')}
                                                                        style={[styles.actionPillButton, styles.declinePill]}
                                                                    >
                                                                        <Ionicons name="close" size={18} color="white"/>
                                                                    </TouchableOpacity>
                                                                </>
                                                            )}
                                                        </View>
                                                    </View>
                                                </View>
                                            )}
                                        />
                                    )}
                                </TouchableOpacity>
                            </KeyboardAvoidingView>
                        </TouchableWithoutFeedback>
                    </TouchableOpacity>
                </Modal>

                {/* Tuile Paramètres */}
                <TouchableOpacity
                    style={[
                        styles.manualTile,
                        currentRoute === 'settings' && {backgroundColor: `${colors.primary}15`}
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
                        Paramètres
                    </Text>
                </TouchableOpacity>
            </ScrollView>
        </View>
    );
}

export function useLayoutAction() {
    const context = useContext(LayoutContext);
    if (!context) {
        throw new Error('useLayoutAction must be used within a LayoutContext.Provider');
    }
    return context;
}

export default function DrawerLayout() {
    const { joinGroup } = useSocket();
    const [invitationModalVisible, setInvitationModalVisible] = useState(false);
    const {groups, activeGroupId} = useGroups();
    const {colors} = useTheme();
    const activeGroup = groups.find(g => g.id === activeGroupId) || {id: '', name: 'None', isShared: false};

    const openInvitationModal = () => {
        setInvitationModalVisible(true);
    };
    useEffect(() => {
        joinGroup(activeGroupId);
    }, [activeGroupId]);

    const handleItemAdded = useCallback((item:  GroceryItem) => {
        console.log(item);
    }, []);
    const handleItemDeleted = useCallback((payload: { id: string; listId: string }) => {

    }, []);
    const handleItemUpdated = useCallback((item: { id: string; updates: Partial<{ name: string; quantity: number }> }) => {

    }, []);
    const handleListAdded = useCallback((item: { id: string; title: string; owner: string }) => {

    }, []);


    useSocketEvent('item_deleted', handleItemDeleted);
    useSocketEvent('item_updated', handleItemUpdated);
    useSocketEvent('list_created', handleListAdded);

    return (
        <LayoutContext.Provider value={{openInvitationModal}}>
            <Drawer
                drawerContent={(props) => (
                    <CustomDrawerContent
                        {...props}
                        invitationModalVisible={invitationModalVisible}
                        setInvitationModalVisible={setInvitationModalVisible}
                    />
                )}
                screenOptions={{
                    headerStyle: {backgroundColor: colors.primary},
                    headerTintColor: colors.text,
                    drawerStyle: {backgroundColor: colors.card},
                    drawerActiveTintColor: colors.primary,
                    drawerInactiveTintColor: colors.subtext,
                }}
            >
                <Drawer.Screen name="home" options={{title: "Dashboard"}}/>
                <Drawer.Screen name="list_selection" options={{title: "Lists"}}/>
            </Drawer>
        </LayoutContext.Provider>
    );
}

const styles = StyleSheet.create({
    dialogCard: {
        width: '90%',
        borderRadius: 20,
        padding: 20,
        borderWidth: 1,
        elevation: 24,
        shadowColor: '#000',
        shadowOffset: {width: 0, height: 10},
        shadowOpacity: 0.3,
        shadowRadius: 12
    },
    modalOverlay: {
        flex: 1,
        backgroundColor: 'rgba(0,0,0,0.6)',
        justifyContent: 'center',
        alignItems: 'center'
    },
    modalHeader: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: 16,
        paddingBottom: 10,
        borderBottomWidth: StyleSheet.hairlineWidth,
        borderBottomColor: 'rgba(150,150,150,0.2)'
    },
    modalHeaderTitle: {
        fontSize: 18,
        fontWeight: '700',
    },
    centeredEmptyState: {
        justifyContent: 'center',
        alignItems: 'center',
        paddingVertical: 32,
    },
    iconCircle: {
        width: 64,
        height: 64,
        borderRadius: 32,
        justifyContent: 'center',
        alignItems: 'center',
        marginBottom: 12
    },
    emptyText: {
        fontSize: 16,
        fontWeight: '600',
        marginTop: 4
    },
    inviteCard: {
        flexDirection: 'row',
        borderRadius: 12,
        borderWidth: 1,
        overflow: 'hidden',
        elevation: 1,
        shadowColor: '#000',
        shadowOffset: {width: 0, height: 1},
        shadowOpacity: 0.1,
        shadowRadius: 2
    },
    cardAccentStrip: {
        width: 5,
        height: '100%'
    },
    inviteCardContent: {
        flex: 1,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingVertical: 14,
        paddingHorizontal: 14,
    },
    inviteGroupName: {
        fontSize: 15,
        fontWeight: '600',
        marginBottom: 2
    },
    inviteOwner: {
        fontSize: 12,
    },
    inviteActionContainer: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    actionPillButton: {
        width: 36,
        height: 36,
        borderRadius: 18,
        justifyContent: 'center',
        alignItems: 'center',
        marginLeft: 8,
    },
    acceptPill: {
        backgroundColor: '#10b981', // Emerald green
    },
    declinePill: {
        backgroundColor: '#ef4444', // Red
    },
    drawerHeader: {
        padding: 20,
        paddingTop: 50,
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
        zIndex: 9999,
        elevation: 9999,
        overflow: 'visible',
    },
    customRow: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
    },
    itemName: {
        fontSize: 16,
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
        paddingHorizontal: 6,
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
    inputLabel: {
        fontSize: 14,
        fontWeight: '600',
        marginBottom: 6,
    },
    textInput: {
        height: 44,
        borderRadius: 8,
        borderWidth: 1,
        paddingHorizontal: 12,
        fontSize: 15,
        marginBottom: 16,
    },
    switchContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: 24,
    },
    switchLabel: {
        fontSize: 14,
        fontWeight: '600',
    },
    submitButton: {
        height: 46,
        borderRadius: 8,
        justifyContent: 'center',
        alignItems: 'center',
    },
    submitButtonText: {
        color: 'white',
        fontSize: 16,
        fontWeight: 'bold',
    },
});