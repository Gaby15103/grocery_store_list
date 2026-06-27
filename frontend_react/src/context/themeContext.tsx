import React, { createContext, useContext, useState, useEffect } from 'react';
import { useColorScheme } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

export type ThemeMode = 'system' | 'light' | 'dark';

export interface ThemeContextType {
    themeMode: ThemeMode;
    isDark: boolean;
    colors: any;
    setTheme: (mode: ThemeMode) => Promise<void>;
    colorSeed: string;
    setColorSeed: (color: string) => Promise<void>;
    isLoading: boolean;
}

// Helper pour injecter une touche de la couleur primaire dans un fond (Gris teinté)
// Surtout efficace pour le mode sombre ou clair personnalisé
function getTintedColor(hexColor: string, isDark: boolean, type: 'bg' | 'card' | 'input') {
    // Si le HEX est invalide, on fallback sur du gris neutre standard
    if (!/^#([A-Fa-f0-9]{3}){1,2}$/.test(hexColor)) {
        if (isDark) return type === 'bg' ? '#121212' : type === 'card' ? '#1c1c1e' : '#2c2c2e';
        return type === 'bg' ? '#f6f6f6' : type === 'card' ? '#ffffff' : '#fafafa';
    }

    // Convertir HEX en RVB
    let c = hexColor.substring(1);
    if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
    let r = parseInt(c.substring(0, 2), 16) / 255;
    let g = parseInt(c.substring(2, 4), 16) / 255;
    let b = parseInt(c.substring(4, 6), 16) / 255;

    // Trouver la Teinte (Hue)
    let max = Math.max(r, g, b), min = Math.min(r, g, b);
    let h = 0;
    if (max !== min) {
        let d = max - min;
        switch (max) {
            case r: h = (g - b) / d + (g < b ? 6 : 0); break;
            case g: h = (b - r) / d + 2; break;
            case b: h = (r - g) / d + 4; break;
        }
        h /= 6;
    }
    h = Math.round(h * 360);

    // Génération des variations teintées (Faible saturation entre 4% et 12%)
    if (isDark) {
        switch (type) {
            case 'bg':    return `hsl(${h}, 10%, 8%)`;   // Fond ultra sombre bleuté/teinté
            case 'card':  return `hsl(${h}, 12%, 13%)`;  // Cartes légèrement plus claires
            case 'input': return `hsl(${h}, 12%, 18%)`;  // Inputs encore un peu plus clairs
        }
    } else {
        switch (type) {
            case 'bg':    return `hsl(${h}, 12%, 96%)`;  // Fond clair teinté
            case 'card':  return `hsl(${h}, 12%, 100%)`; // Blanc pur ou presque blanc teinté
            case 'input': return `hsl(${h}, 8%, 93%)`;   // Input légèrement grisé-teinté
        }
    }
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
    const systemColorScheme = useColorScheme();
    const [themeMode, setThemeModeState] = useState<ThemeMode>('system');
    const [colorSeed, setColorSeedState] = useState<string>('#007AFF'); // Bleu par défaut
    const [isLoading, setIsLoading] = useState(true);

    useEffect(() => {
        const loadPreferences = async () => {
            try {
                const [savedTheme, savedColor] = await Promise.all([
                    AsyncStorage.getItem('@user_theme'),
                    AsyncStorage.getItem('@user_color_seed')
                ]);

                if (savedTheme) setThemeModeState(savedTheme as ThemeMode);
                if (savedColor) setColorSeedState(savedColor);
            } catch (e) {
                console.error("Failed to load theme preferences", e);
            } finally {
                setIsLoading(false);
            }
        };
        loadPreferences();
    }, []);

    const isDark = themeMode === 'system' ? systemColorScheme === 'dark' : themeMode === 'dark';

    // Génération dynamique des couleurs d'arrière-plan basées sur la graine (colorSeed)
    const dynamicBackground = getTintedColor(colorSeed, isDark, 'bg');
    const dynamicCard = getTintedColor(colorSeed, isDark, 'card');
    const dynamicInput = getTintedColor(colorSeed, isDark, 'input');

    const colors = {
        primary: colorSeed,
        background: dynamicBackground,
        card: dynamicCard,
        inputBg: dynamicInput,

        // On conserve le reste en sémantique standard ajusté selon le mode
        text: isDark ? '#ffffff' : '#1c1c1e',
        subtext: isDark ? '#aeaeb2' : '#636366',
        muted: isDark ? '#636366' : '#8e8e93',
        inputBorder: isDark ? 'transparent' : '#e5e5ea',
        border: isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)',
        success: isDark ? '#30d158' : '#34c759',
        warning: isDark ? '#ff9f0a' : '#ff9500',
        danger: isDark ? '#ff453a' : '#ff3b30',
    };

    const setTheme = async (mode: ThemeMode) => {
        try {
            setThemeModeState(mode);
            await AsyncStorage.setItem('@user_theme', mode);
        } catch (e) {
            console.error(e);
        }
    };

    const setColorSeed = async (color: string) => {
        try {
            setColorSeedState(color);
            await AsyncStorage.setItem('@user_color_seed', color);
        } catch (e) {
            console.error(e);
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