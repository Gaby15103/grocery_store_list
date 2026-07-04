import React, { useState, useEffect } from 'react';
import {View, Text, TouchableOpacity, FlatList, StyleSheet, ScrollView} from 'react-native';

interface CustomDropdownProps<T> {
    data: T[];
    defaultValue?: T | null;
    placeholder?: string;
    onSelect: (item: T) => void;
    getLabel: (item: T) => string;
    getValue: (item: T) => string | number;
    renderCustomItem?: (item: T) => React.ReactNode;
    colors: {
        text: string;
        subtext: string;
        border: string;
        background: string;
        card: string;
        primary: string;
        inputBg: string;
        inputBorder: string;
    };
}

function CustomDropdown<T>({
                               data,
                               defaultValue = null,
                               placeholder = 'Select an option',
                               onSelect,
                               getLabel,
                               getValue,
                               renderCustomItem,
                               colors,
                           }: CustomDropdownProps<T>) {
    const [isOpen, setIsOpen] = useState(false);
    const [selectedItem, setSelectedItem] = useState<T | null>(defaultValue);

    // Sync state if defaultValue changes upstream
    useEffect(() => {
        setSelectedItem(defaultValue);
    }, [defaultValue]);

    const toggleDropdown = () => setIsOpen(!isOpen);

    const handleSelect = (item: T) => {
        setSelectedItem(item);
        setIsOpen(false);
        onSelect(item);
    };

    return (
        <View style={styles.container}>
            {/* Dropdown Button Trigger */}
            <TouchableOpacity
                style={[
                    styles.triggerButton,
                    { backgroundColor: colors.inputBg, borderColor: colors.border, marginBottom: 10 }
                ]}
                onPress={toggleDropdown}
            >
                <Text style={[styles.triggerText, { color: selectedItem ? colors.text : colors.subtext }]}>
                    {selectedItem ? getLabel(selectedItem) : placeholder}
                </Text>
                <Text style={[styles.arrowIcon, { color: colors.subtext }]}>
                    {isOpen ? '▲' : '▼'}
                </Text>
            </TouchableOpacity>

            {/* Floating Options List Overlay */}
            {isOpen && (
                <View style={[styles.dropdownOverlay, { backgroundColor: colors.card, borderColor: colors.border }]}>
                    <ScrollView
                        nestedScrollEnabled={true}
                        keyboardShouldPersistTaps="handled"
                        style={{ maxHeight: 285 }}
                    >
                        {data.map((item) => (
                            <TouchableOpacity
                                key={getValue(item).toString()}
                                style={[styles.optionItem, { borderBottomColor: colors.border }]}
                                onPress={() => handleSelect(item)}
                            >
                                {renderCustomItem ? (
                                    renderCustomItem(item)
                                ) : (
                                    <Text style={[styles.optionText, { color: colors.text }]}>
                                        {getLabel(item)}
                                    </Text>
                                )}
                            </TouchableOpacity>
                        ))}
                    </ScrollView>
                </View>
            )}
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        width: '100%',
        zIndex: 5000,
        position: 'relative',
    },
    triggerButton: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 16,
        paddingVertical: 12,
    },
    triggerText: {
        fontSize: 16,
    },
    arrowIcon: {
        fontSize: 14,
    },
    dropdownOverlay: {
        position: 'absolute',
        top: '100%', // Sits directly below the trigger button
        left: 0,
        right: 0,
        borderWidth: 1,
        borderRadius: 8,
        maxHeight: 285,
        elevation: 10,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.2,
        shadowRadius: 4,
    },
    optionItem: {
        paddingHorizontal: 16,
        paddingVertical: 12,
        borderBottomWidth: StyleSheet.hairlineWidth,
    },
    optionText: {
        fontSize: 16,
    },
});

export default CustomDropdown;