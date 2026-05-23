import { useLocalSearchParams } from 'expo-router';
import { EventDetailScreen } from '../../src/features/EventDetailScreen';

export default function EventPage() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <EventDetailScreen eventId={id} />;
}
