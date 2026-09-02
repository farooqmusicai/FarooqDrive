import fs from 'node:fs';
import path from 'node:path';
import { db } from './database.js';

export function migrate(migrationDir: string) {
  db().exec('CREATE TABLE IF NOT EXISTS schema_migrations (id TEXT PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);');
  const applied = new Set((db().prepare('SELECT id FROM schema_migrations').all() as any[]).map(r => r.id));
  const files = fs.readdirSync(migrationDir).filter(f => f.endsWith('.sql')).sort();
  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = fs.readFileSync(path.join(migrationDir, file), 'utf8');
    db().exec('BEGIN IMMEDIATE');
    try {
      db().exec(sql);
      db().prepare('INSERT INTO schema_migrations (id) VALUES (?)').run(file);
      db().exec('COMMIT');
    } catch (error) {
      db().exec('ROLLBACK');
      throw error;
    }
  }
}
