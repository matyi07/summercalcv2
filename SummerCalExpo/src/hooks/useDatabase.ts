import { useEffect, useState } from 'react';
import { getDatabase } from '../db/database';
import { SQLiteDatabase } from 'expo-sqlite';

export function useDatabase() {
  const [db, setDb] = useState<SQLiteDatabase | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    getDatabase().then(database => {
      setDb(database);
      setReady(true);
    });
  }, []);

  return { db, ready };
}
