import { Tabs } from 'expo-router';
import { Text } from 'react-native';
import { Colors } from '../../src/constants/theme';

export default function TabLayout() {
  return (
    <Tabs screenOptions={{
      tabBarActiveTintColor: Colors.primary,
      tabBarInactiveTintColor: Colors.textSecondary,
      tabBarStyle: { backgroundColor: Colors.background, borderTopColor: Colors.border },
      headerStyle: { backgroundColor: Colors.background },
      headerTitleStyle: { fontWeight: '700', color: Colors.text },
    }}>
      <Tabs.Screen
        name="index"
        options={{
          title: 'Today',
          tabBarIcon: ({ size }) => <Text style={{ fontSize: size }}>🏠</Text>,
        }}
      />
      <Tabs.Screen
        name="calendar"
        options={{
          title: 'Calendar',
          tabBarIcon: ({ size }) => <Text style={{ fontSize: size }}>📅</Text>,
        }}
      />
      <Tabs.Screen
        name="places"
        options={{
          title: 'Places',
          tabBarIcon: ({ size }) => <Text style={{ fontSize: size }}>📍</Text>,
        }}
      />
      <Tabs.Screen
        name="money"
        options={{
          title: 'Money',
          tabBarIcon: ({ size }) => <Text style={{ fontSize: size }}>💰</Text>,
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: 'Settings',
          tabBarIcon: ({ size }) => <Text style={{ fontSize: size }}>⚙️</Text>,
        }}
      />
    </Tabs>
  );
}
