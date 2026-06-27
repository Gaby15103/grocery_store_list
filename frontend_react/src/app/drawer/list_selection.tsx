import React, {useEffect, useRef} from 'react';
import {View, Text, StyleSheet, FlatList, TouchableOpacity, StatusBar} from 'react-native';
import {router, Stack, useLocalSearchParams} from 'expo-router';
import { ChevronRight } from 'lucide-react-native';
import {useGroups} from "@/context/groupContext";
import {useLists} from "@/context/listContext"
import {GroceryList} from "@/types/models";
import {useTheme} from "@/context/themeContext";
import {Ionicons} from "@expo/vector-icons";
export default function ListSelectionScreen() {
    const { groupId, refreshKey } = useLocalSearchParams<{ groupId: string, refreshKey: string }>();
    const {groups, activeGroupId, changeActiveGroup} = useGroups();
    const {loadLists, lists} = useLists();
    const { colors } = useTheme();

    const lastLoadedGroupId = useRef<string | null>(null);

    useEffect(() => {
        if (groupId) {

            lastLoadedGroupId.current = groupId;

            loadLists(groupId, true);
        }
        return () => {
            if (!groupId) {
                lastLoadedGroupId.current = null;
            }
        };
    }, [groupId, refreshKey]);

    const onPress = (listId: string) => {
        router.replace({ pathname: '/drawer/grocery_list_view', params: { sessionId: listId,
                refreshKey: Date.now().toString()
            } });
    }

    const renderItem = ({ item }: { item: GroceryList }) => {
        const dateObj = new Date(item.createdAt);

        const day = String(dateObj.getDate()).padStart(2, '0');
        const month = String(dateObj.getMonth() + 1).padStart(2, '0'); // Months are 0-11
        const year = dateObj.getFullYear();

        const dataString = `${day}/${month}/${year}`;

        return (
            <TouchableOpacity onPress={() => onPress(item.id)} style={[styles.item, {backgroundColor: colors.card}]}>
                <View style={styles.textContainer}>
                    <Text style={[styles.title,{color: colors.text}]}>{item.name}</Text>
                    <Text style={[styles.data,{color: colors.subtext}]}>Créée le {dataString}</Text>
                </View>
                <ChevronRight size={20} color="#8e8e93" />
            </TouchableOpacity>
        );
    };

    return (
        <View style={{backgroundColor: colors.background, flex: 1}}>
            <Stack.Screen
                options={{
                    headerLeft: () => (
                        <TouchableOpacity
                            onPress={() => router.replace({pathname: '/drawer/home'})}
                            style={{ marginLeft: 16, marginRight: 5 }}
                        >
                            <Ionicons
                                name="arrow-back"
                                size={24}
                                color={colors.text}
                            />
                        </TouchableOpacity>
                    ),
                }}
            />
            <FlatList
                data={lists}
                renderItem={renderItem}
                keyExtractor={(item) => item.id}
                contentContainerStyle={styles.listContent}
            />
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    listContent: {
        paddingHorizontal: 16,
        paddingVertical: 12,
    },
    item: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        backgroundColor: '#dad4d4',
        paddingVertical: 16,
        paddingHorizontal: 16,
        borderBottomWidth: 1,
        borderBottomColor: '#e5e5ea',
        marginVertical: 6,
        borderRadius: 12,
        borderWidth: 1,
        borderColor: '#e5e5ea',
    },
    itemHovered: {
        backgroundColor: '#f2f2f7',
    },
    itemPressed: {
        backgroundColor: '#e5e5ea',
    },
    textContainer: {
        flex: 1,
    },
    title: {
        fontSize: 17,
        fontWeight: '600',
        color: '#1c1c1e',
        marginBottom: 4,
    },
    data: {
        fontSize: 13,
        color: '#8e8e93',
    },
    chevron: {
        marginLeft: 8,
    }
});