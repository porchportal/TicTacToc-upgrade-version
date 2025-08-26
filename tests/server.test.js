const request = require('supertest');
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Import the server app
const app = require('../server');

describe('TicTacToe API', () => {
  let testDb;
  let gameId;

  beforeAll((done) => {
    // Create a test database
    testDb = new sqlite3.Database(':memory:', (err) => {
      if (err) {
        console.error('Error opening test database:', err.message);
      } else {
        console.log('Connected to test database');
        // Initialize test database
        testDb.serialize(() => {
          testDb.run(`CREATE TABLE IF NOT EXISTS games (
            id TEXT PRIMARY KEY,
            board TEXT NOT NULL,
            current_player TEXT NOT NULL,
            winner TEXT,
            is_draw BOOLEAN DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )`);

          testDb.run(`CREATE TABLE IF NOT EXISTS moves (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id TEXT NOT NULL,
            player TEXT NOT NULL,
            position INTEGER NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (game_id) REFERENCES games (id)
          )`);

          testDb.run(`CREATE TABLE IF NOT EXISTS player_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_name TEXT UNIQUE NOT NULL,
            wins INTEGER DEFAULT 0,
            losses INTEGER DEFAULT 0,
            draws INTEGER DEFAULT 0,
            total_games INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )`);
        });
        done();
      }
    });
  });

  afterAll((done) => {
    testDb.close((err) => {
      if (err) {
        console.error('Error closing test database:', err.message);
      } else {
        console.log('Test database connection closed.');
      }
      done();
    });
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app).get('/health');
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
    });
  });

  describe('POST /api/games', () => {
    it('should create a new game', async () => {
      const response = await request(app)
        .post('/api/games')
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('board');
      expect(response.body).toHaveProperty('currentPlayer', 'X');
      expect(response.body).toHaveProperty('winner', null);
      expect(response.body).toHaveProperty('isDraw', false);
      expect(response.body.board).toHaveLength(9);
      expect(response.body.board.every(cell => cell === '')).toBe(true);

      gameId = response.body.id;
    });
  });

  describe('GET /api/games/:id', () => {
    it('should get a game by ID', async () => {
      const response = await request(app)
        .get(`/api/games/${gameId}`)
        .expect(200);

      expect(response.body).toHaveProperty('id', gameId);
      expect(response.body).toHaveProperty('board');
      expect(response.body).toHaveProperty('currentPlayer');
      expect(response.body).toHaveProperty('winner');
      expect(response.body).toHaveProperty('isDraw');
    });

    it('should return 404 for non-existent game', async () => {
      await request(app)
        .get('/api/games/non-existent-id')
        .expect(404);
    });
  });

  describe('POST /api/games/:id/move', () => {
    it('should make a valid move', async () => {
      const response = await request(app)
        .post(`/api/games/${gameId}/move`)
        .send({
          position: 0,
          player: 'X'
        })
        .expect(200);

      expect(response.body).toHaveProperty('id', gameId);
      expect(response.body).toHaveProperty('board');
      expect(response.body).toHaveProperty('currentPlayer', 'O');
      expect(response.body.board[0]).toBe('X');
    });

    it('should reject invalid position', async () => {
      await request(app)
        .post(`/api/games/${gameId}/move`)
        .send({
          position: 10,
          player: 'O'
        })
        .expect(400);
    });

    it('should reject move on occupied position', async () => {
      await request(app)
        .post(`/api/games/${gameId}/move`)
        .send({
          position: 0,
          player: 'O'
        })
        .expect(400);
    });

    it('should reject wrong player turn', async () => {
      await request(app)
        .post(`/api/games/${gameId}/move`)
        .send({
          position: 1,
          player: 'X'
        })
        .expect(400);
    });
  });

  describe('GET /api/stats', () => {
    it('should return player statistics', async () => {
      const response = await request(app)
        .get('/api/stats')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('Game completion scenarios', () => {
    let winningGameId;

    beforeEach(async () => {
      const createResponse = await request(app).post('/api/games');
      winningGameId = createResponse.body.id;
    });

    it('should detect a winning game', async () => {
      // Make moves to create a winning scenario for X
      const moves = [
        { position: 0, player: 'X' },
        { position: 3, player: 'O' },
        { position: 1, player: 'X' },
        { position: 4, player: 'O' },
        { position: 2, player: 'X' }
      ];

      for (const move of moves) {
        await request(app)
          .post(`/api/games/${winningGameId}/move`)
          .send(move);
      }

      const gameResponse = await request(app)
        .get(`/api/games/${winningGameId}`);

      expect(gameResponse.body.winner).toBe('X');
      expect(gameResponse.body.isDraw).toBe(false);
    });

    it('should detect a draw game', async () => {
      // Make moves to create a draw scenario
      const moves = [
        { position: 0, player: 'X' }, { position: 1, player: 'O' }, { position: 2, player: 'X' },
        { position: 3, player: 'O' }, { position: 4, player: 'X' }, { position: 5, player: 'O' },
        { position: 6, player: 'X' }, { position: 7, player: 'O' }, { position: 8, player: 'X' }
      ];

      for (const move of moves) {
        await request(app)
          .post(`/api/games/${winningGameId}/move`)
          .send(move);
      }

      const gameResponse = await request(app)
        .get(`/api/games/${winningGameId}`);

      expect(gameResponse.body.winner).toBe(null);
      expect(gameResponse.body.isDraw).toBe(true);
    });
  });
});
