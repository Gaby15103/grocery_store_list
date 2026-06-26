// src/app/drawer/home.tsx
import React from 'react';
import { View, Text } from 'react-native';
import { useTheme } from "@/context/themeContext";

export default function HomeScreen() {
    const { colors } = useTheme();
    return (
        <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: colors.background }}>
            <Text>Dashboard Ready</Text>
        </View>
    );
}