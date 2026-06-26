import React, { createContext, useContext, useState, useEffect } from 'react';
import { useColorScheme } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

export type ThemeMode = 'system' | 'light' | 'dark';

interface ThemeContextType {
    themeMode: ThemeMode;
    isDark: boolean;
    colors: typeof lightColors;
    setTheme: (mode: ThemeMode) => Promise<void>;
    colorSeed: string;
    setColorSeed: (color: string) => Promise<void>;
    isLoading: boolean;
}

const lightColors = {
    background: '#f6f6f6',
    card: '#ffffff',
    text: '#1c1c1e',
    subtext: '#8e8e93',
    border: '#e5e5ea',
    primary: '#007AFF',
};

const darkColors = {
    background: '#1c1c1e',
    card: '#2c2c2e',
    text: '#ffffff',
    subtext: '#eaeaea',
    border: '#3a3a3c',
    primary: '#0a84ff',
};

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
    const systemColorScheme = useColorScheme();
    const [themeMode, setThemeModeState] = useState<ThemeMode>('system');
    const [colorSeed, setColorSeedState] = useState<string>('#22c55e'); // Default green seed
    const [isLoading, setIsLoading] = useState(true);

    useEffect(() => {
        const loadPreferences = async () => {
            try {
                const [savedTheme, savedColor] = await Promise.all([
                    AsyncStorage.getItem('@user_theme'),
                    AsyncStorage.getItem('@user_color_seed')
                ]);

                if (savedTheme) {
                    setThemeModeState(savedTheme as ThemeMode);
                }
                if (savedColor) {
                    setColorSeedState(savedColor);
                }
            } catch (e) {
                console.error("Failed to load theme preferences", e);
            } finally {
                setIsLoading(false);
            }
        };
        loadPreferences();
    }, []);

    const isDark = themeMode === 'system'
        ? systemColorScheme === 'dark'
        : themeMode === 'dark';

    const baseColors = isDark ? darkColors : lightColors;
    const colors = {
        ...baseColors,
        primary: colorSeed,
    };

    const setTheme = async (mode: ThemeMode) => {
        try {
            setThemeModeState(mode);
            await AsyncStorage.setItem('@user_theme', mode);
        } catch (e) {
            console.error("Failed to save theme choice", e);
        }
    };

    const setColorSeed = async (color: string) => {
        try {
            setColorSeedState(color);
            await AsyncStorage.setItem('@user_color_seed', color);
        } catch (e) {
            console.error("Failed to save color seed choice", e);
        }
    };

    return (
        <ThemeContext.Provider value={{ themeMode, isDark, colors, setTheme, colorSeed, setColorSeed, isLoading }}>
            {children}
        </ThemeContext.Provider>
    );
}

export const useTheme = () => {
    const context = useContext(ThemeContext);
    if (!context) throw new Error('useTheme must be used within a ThemeProvider');
    return context;
};