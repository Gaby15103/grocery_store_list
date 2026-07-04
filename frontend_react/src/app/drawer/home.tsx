import React from 'react';
import {View, Text, StyleSheet, ScrollView, TouchableOpacity, FlatList} from 'react-native';
import {useRouter} from 'expo-router';
import * as Linking from 'expo-linking';
import {Ionicons} from '@expo/vector-icons';

import {useGroups} from "@/context/groupContext";
import {useAuth} from "@/context/authContext";
import {useTheme} from "@/context/themeContext";
import {GroceryGroup} from "@/types/models";

import { useLayoutAction } from './_layout';

export default function HomeScreen() {
    const { openInvitationModal } = useLayoutAction();

    const {groups, changeActiveGroup} = useGroups();
    const {isLoggedIn, userProfile, refreshSocialData} = useAuth();
    const {colors} = useTheme();
    const router = useRouter();

    const launchRecipeSite = async () => {
        try {
            await Linking.openURL('https://recipes.gaby15103.org/recipes');
        } catch (error) {
            console.error("Error: Could not launch recipe site", error);
        }
    };

    const handleGroupPress = async (groupId: string) => {
        await changeActiveGroup(groupId);
        router.push({pathname: '/drawer/list_selection', params: {groupId}});
    };

    // Horizontal Render Item for Recent Groups
    const renderRecentCard = ({item}: { item: GroceryGroup }) => (
        <TouchableOpacity
            style={[styles.recentCard, {backgroundColor: colors.card, borderColor: colors.border}]}
            onPress={() => handleGroupPress(item.id)}
            activeOpacity={0.7}
        >
            <Ionicons
                name={item.isShared ? "cloud-outline" : "home-outline"}
                size={20}
                color={item.isShared ? "#3b82f6" : "#10b981"}
            />
            <Text
                style={[styles.cardTitle, {color: colors.text}]}
                numberOfLines={1}
            >
                {item.name}
            </Text>
            <Text style={[styles.cardSubtitle, {color: colors.subtext}]}>
                Groupe actif
            </Text>
        </TouchableOpacity>
    );

    return (
        <ScrollView
            style={[styles.container, {backgroundColor: colors.background}]}
            contentContainerStyle={styles.scrollContent}
            bounces={false}
        >

            <View style={styles.welcomeSection}>
                <Text style={[styles.welcomeText, {color: colors.text}]}>
                    Bienvenue, {userProfile?.firstName || 'Chef'}
                </Text>
                <Text style={[styles.statusText, {color: colors.subtext}]}>
                    État de la cuisine
                </Text>
            </View>

            <View style={styles.sectionHeader}>
                <Text style={[styles.sectionTitle, {color: colors.text}]}>Recent</Text>
            </View>
            <View>
                <FlatList
                    horizontal
                    showsHorizontalScrollIndicator={false}
                    data={groups.slice(0, 5)}
                    renderItem={renderRecentCard}
                    keyExtractor={(item) => item.id}
                    contentContainerStyle={styles.horizontalListPadding}
                />
            </View>
            <View style={[
                styles.statusBanner,
                {
                    backgroundColor: isLoggedIn ? 'rgba(59, 130, 246, 0.1)' : 'rgba(249, 115, 22, 0.1)',
                    borderColor: isLoggedIn ? '#3b82f6' : '#f97316'
                }
            ]}>
                <Ionicons
                    name={isLoggedIn ? "checkmark-circle" : "warning"}
                    size={24}
                    color={isLoggedIn ? "#3b82f6" : "#f97316"}
                />
                <View style={styles.bannerTextContainer}>
                    <Text style={[styles.bannerTitle, {color: colors.text}]}>
                        {isLoggedIn ? "Statut en ligne" : "Statut hors ligne"}
                    </Text>
                    <Text style={[styles.bannerSubtitle, {color: colors.subtext}]}>
                        {isLoggedIn ? "Synchronisation cloud activée" : "Synchronisation désactivée"}
                    </Text>
                </View>
            </View>

            <View style={styles.sectionHeader}>
                <Text style={[styles.sectionTitle, {color: colors.text}]}>Accès rapide</Text>
            </View>

            <View style={styles.gridContainer}>
                <TouchableOpacity
                    style={[styles.actionCard, {backgroundColor: 'rgba(249, 115, 22, 0.1)'}]}
                    onPress={launchRecipeSite}
                    activeOpacity={0.7}
                >
                    <Ionicons name="book-outline" size={32} color="#f97316"/>
                    <Text style={[styles.actionCardText, {color: '#f97316'}]}>Recettes</Text>
                </TouchableOpacity>

                <TouchableOpacity
                    style={[styles.actionCard, {backgroundColor: 'rgba(59, 130, 246, 0.1)'}]}
                    onPress={openInvitationModal}
                    activeOpacity={0.7}
                >
                    <Ionicons name="mail-outline" size={32} color="#3b82f6"/>
                    <Text style={[styles.actionCardText, {color: '#3b82f6'}]}>Invitations</Text>
                </TouchableOpacity>
            </View>
        </ScrollView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    scrollContent: {
        paddingBottom: 24,
    },
    welcomeSection: {
        paddingHorizontal: 16,
        paddingTop: 16,
        paddingBottom: 8,
    },
    welcomeText: {
        fontSize: 24,
        fontWeight: 'bold',
    },
    statusText: {
        fontSize: 14,
        marginTop: 2,
    },
    sectionHeader: {
        paddingHorizontal: 16,
        marginTop: 20,
        marginBottom: 8,
    },
    sectionTitle: {
        fontSize: 18,
        fontWeight: 'bold',
    },
    horizontalListPadding: {
        paddingHorizontal: 10,
    },
    recentCard: {
        width: 140,
        height: 110,
        padding: 12,
        marginHorizontal: 6,
        marginVertical: 4,
        borderRadius: 12,
        borderWidth: 1,
        justifyContent: 'space-between',
        alignItems: 'flex-start',
    },
    cardTitle: {
        fontSize: 14,
        fontWeight: 'bold',
        marginTop: 8,
        width: '100%',
    },
    cardSubtitle: {
        fontSize: 10,
    },
    statusBanner: {
        flexDirection: 'row',
        alignItems: 'center',
        marginHorizontal: 16,
        marginTop: 24,
        padding: 12,
        borderRadius: 12,
        borderWidth: 1,
    },
    bannerTextContainer: {
        marginLeft: 12,
        flex: 1,
    },
    bannerTitle: {
        fontSize: 14,
        fontWeight: 'bold',
    },
    bannerSubtitle: {
        fontSize: 12,
        marginTop: 1,
    },
    gridContainer: {
        flexDirection: 'row',
        paddingHorizontal: 16,
        justifyContent: 'space-between',
    },
    actionCard: {
        flex: 1,
        height: 95,
        marginHorizontal: 6,
        borderRadius: 12,
        justifyContent: 'center',
        alignItems: 'center',
    },
    actionCardText: {
        marginTop: 8,
        fontWeight: 'bold',
        fontSize: 14,
    },
});