import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

let database: DatabaseSync | null = null;

export function initDatabase(dataDir: string) {
  if (database) return database;
  fs.mkdirSync(dataDir, { recursive: true });
  const dbPath = path.join(dataDir, 'farooqdrive.db');
  database = new DatabaseSync(dbPath);
  database.exec('PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL;');
  return database;
}

export function db() {
  if (!database) throw new Error('Database has not been initialized');
  return database;
}

export function run(sql: string, params: any[] = []) {
  return db().prepare(sql).run(...params);
}

export function get<T = any>(sql: string, params: any[] = []): T | undefined {
  return db().prepare(sql).get(...params) as T | undefined;
}

export function all<T = any>(sql: string, params: any[] = []): T[] {
  return db().prepare(sql).all(...params) as T[];
}
