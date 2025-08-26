const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const sqlite3 = require('sqlite3').verbose();
const { v4: uuidv4 } = require('uuid');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
// Serve static files with error handling
app.use(express.static('public', {
    setHeaders: (res, path, stat) => {
        // Add cache headers for better performance
        res.set('Cache-Control', 'public, max-age=3600');
    }
}));

// Handle static file errors
app.use('/public', (err, req, res, next) => {
    console.error('Static file error:', err);
    res.status(404).json({ error: 'Static file not found' });
});

// Database setup
const dbPath = process.env.DB_PATH || './data/tictactoe.db';
const db = new sqlite3.Database(dbPath, (err) => {
    if (err) {
        console.error('Error opening database:', err.message);
    } else {
        console.log('Connected to SQLite database');
        initDatabase();
    }
});

// Initialize database tables
function initDatabase() {
    db.serialize(() => {
        // Games table
        db.run(`CREATE TABLE IF NOT EXISTS games (
            id TEXT PRIMARY KEY,
            board TEXT NOT NULL,
            current_player TEXT NOT NULL,
            winner TEXT,
            is_draw BOOLEAN DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )`);

        // Game moves table
        db.run(`CREATE TABLE IF NOT EXISTS moves (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id TEXT NOT NULL,
            player TEXT NOT NULL,
            position INTEGER NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (game_id) REFERENCES games (id)
        )`);

        // Player stats table
        db.run(`CREATE TABLE IF NOT EXISTS player_stats (
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
}

// Game logic
const winPatterns = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
    [0, 4, 8], [2, 4, 6] // diagonals
];

function checkWinner(board) {
    for (let pattern of winPatterns) {
        const [a, b, c] = pattern;
        if (board[a] && board[a] === board[b] && board[a] === board[c]) {
            return board[a];
        }
    }
    return null;
}

function checkForDraw(board) {
    return board.every(cell => cell !== '');
}

// API Routes

// Create new game
app.post('/api/games', (req, res) => {
    const gameId = uuidv4();
    const board = Array(9).fill('');
    const currentPlayer = 'X';

    db.run(
        'INSERT INTO games (id, board, current_player) VALUES (?, ?, ?)',
        [gameId, JSON.stringify(board), currentPlayer],
        function(err) {
            if (err) {
                console.error('Error creating game:', err);
                return res.status(500).json({ error: 'Failed to create game' });
            }
            res.status(201).json({
                id: gameId,
                board: board,
                currentPlayer: currentPlayer,
                winner: null,
                isDraw: false
            });
        }
    );
});

// Get game by ID
app.get('/api/games/:id', (req, res) => {
    const gameId = req.params.id;

    db.get(
        'SELECT * FROM games WHERE id = ?',
        [gameId],
        (err, row) => {
            if (err) {
                console.error('Error fetching game:', err);
                return res.status(500).json({ error: 'Failed to fetch game' });
            }
            if (!row) {
                return res.status(404).json({ error: 'Game not found' });
            }
            res.json({
                id: row.id,
                board: JSON.parse(row.board),
                currentPlayer: row.current_player,
                winner: row.winner,
                isDraw: Boolean(row.is_draw),
                createdAt: row.created_at,
                updatedAt: row.updated_at
            });
        }
    );
});

// Make a move
app.post('/api/games/:id/move', (req, res) => {
    const gameId = req.params.id;
    const { position, player } = req.body;

    if (position === undefined || player === undefined) {
        return res.status(400).json({ error: 'Position and player are required' });
    }

    if (position < 0 || position > 8) {
        return res.status(400).json({ error: 'Invalid position' });
    }

    db.get(
        'SELECT * FROM games WHERE id = ?',
        [gameId],
        (err, game) => {
            if (err) {
                console.error('Error fetching game:', err);
                return res.status(500).json({ error: 'Failed to fetch game' });
            }
            if (!game) {
                return res.status(404).json({ error: 'Game not found' });
            }

            const board = JSON.parse(game.board);
            const currentPlayer = game.current_player;

            if (player !== currentPlayer) {
                return res.status(400).json({ error: 'Not your turn' });
            }

            if (board[position] !== '') {
                return res.status(400).json({ error: 'Position already taken' });
            }

            if (game.winner || game.is_draw) {
                return res.status(400).json({ error: 'Game is already finished' });
            }

            // Make the move
            board[position] = player;
            const nextPlayer = player === 'X' ? 'O' : 'X';

            // Check for winner
            const winner = checkWinner(board);
            const isDraw = !winner && checkForDraw(board);

            // Save move to database
            db.run(
                'INSERT INTO moves (game_id, player, position) VALUES (?, ?, ?)',
                [gameId, player, position],
                function(err) {
                    if (err) {
                        console.error('Error saving move:', err);
                        return res.status(500).json({ error: 'Failed to save move' });
                    }

                    // Update game state
                    db.run(
                        'UPDATE games SET board = ?, current_player = ?, winner = ?, is_draw = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                        [JSON.stringify(board), nextPlayer, winner, isDraw, gameId],
                        function(err) {
                            if (err) {
                                console.error('Error updating game:', err);
                                return res.status(500).json({ error: 'Failed to update game' });
                            }

                            // Update player stats if game is finished
                            if (winner || isDraw) {
                                updatePlayerStats(winner, isDraw);
                            }

                            res.json({
                                id: gameId,
                                board: board,
                                currentPlayer: nextPlayer,
                                winner: winner,
                                isDraw: isDraw,
                                move: { position, player }
                            });
                        }
                    );
                }
            );
        }
    );
});

// Get all games with detailed information
app.get('/api/games', (req, res) => {
    db.all(
        `SELECT g.*, 
                COUNT(m.id) as total_moves,
                GROUP_CONCAT(m.player || ':' || m.position) as move_history
         FROM games g 
         LEFT JOIN moves m ON g.id = m.game_id 
         GROUP BY g.id 
         ORDER BY g.created_at DESC 
         LIMIT 50`,
        (err, rows) => {
            if (err) {
                console.error('Error fetching games:', err);
                return res.status(500).json({ error: 'Failed to fetch games' });
            }
            res.json(rows.map(row => ({
                id: row.id,
                board: JSON.parse(row.board),
                currentPlayer: row.current_player,
                winner: row.winner,
                isDraw: Boolean(row.is_draw),
                totalMoves: row.total_moves || 0,
                moveHistory: row.move_history ? row.move_history.split(',').map(move => {
                    const [player, position] = move.split(':');
                    return { player, position: parseInt(position) };
                }) : [],
                createdAt: row.created_at,
                updatedAt: row.updated_at
            })));
        }
    );
});

// Get player statistics
app.get('/api/stats', (req, res) => {
    db.all(
        'SELECT * FROM player_stats ORDER BY wins DESC',
        (err, rows) => {
            if (err) {
                console.error('Error fetching stats:', err);
                return res.status(500).json({ error: 'Failed to fetch stats' });
            }
            res.json(rows);
        }
    );
});

// Update player statistics
function updatePlayerStats(winner, isDraw) {
    if (isDraw) {
        db.run(
            'INSERT OR REPLACE INTO player_stats (player_name, draws, total_games, updated_at) VALUES (?, COALESCE((SELECT draws FROM player_stats WHERE player_name = ?), 0) + 1, COALESCE((SELECT total_games FROM player_stats WHERE player_name = ?), 0) + 1, CURRENT_TIMESTAMP)',
            ['Draw', 'Draw', 'Draw']
        );
    } else if (winner) {
        const loser = winner === 'X' ? 'O' : 'X';
        
        // Update winner stats
        db.run(
            'INSERT OR REPLACE INTO player_stats (player_name, wins, total_games, updated_at) VALUES (?, COALESCE((SELECT wins FROM player_stats WHERE player_name = ?), 0) + 1, COALESCE((SELECT total_games FROM player_stats WHERE player_name = ?), 0) + 1, CURRENT_TIMESTAMP)',
            [winner, winner, winner]
        );

        // Update loser stats
        db.run(
            'INSERT OR REPLACE INTO player_stats (player_name, losses, total_games, updated_at) VALUES (?, COALESCE((SELECT losses FROM player_stats WHERE player_name = ?), 0) + 1, COALESCE((SELECT total_games FROM player_stats WHERE player_name = ?), 0) + 1, CURRENT_TIMESTAMP)',
            [loser, loser, loser]
        );
    }
}

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Serve the main application
app.get('/', (req, res) => {
    const indexPath = path.join(__dirname, 'public', 'index.html');
    
    // Check if file exists
    if (!require('fs').existsSync(indexPath)) {
        console.error('index.html not found at:', indexPath);
        // Serve a basic fallback HTML
        return res.send(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>TicTacToe Game</title>
                <style>
                    body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                    .error { color: red; }
                    .info { color: blue; }
                </style>
            </head>
            <body>
                <h1>TicTacToe Game</h1>
                <p class="error">Application files not found at: ${indexPath}</p>
                <p class="info">Health check: <a href="/health">/health</a></p>
                <p>API endpoints are available at /api/*</p>
            </body>
            </html>
        `);
    }
    
    res.sendFile(indexPath, (err) => {
        if (err) {
            console.error('Error serving index.html:', err);
            // Serve a basic fallback HTML
            res.send(`
                <!DOCTYPE html>
                <html>
                <head>
                    <title>TicTacToe Game</title>
                    <style>
                        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                        .error { color: red; }
                        .info { color: blue; }
                    </style>
                </head>
                <body>
                    <h1>TicTacToe Game</h1>
                    <p class="error">Failed to serve application: ${err.message}</p>
                    <p class="info">Health check: <a href="/health">/health</a></p>
                    <p>API endpoints are available at /api/*</p>
                </body>
                </html>
            `);
        }
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
});

// Graceful shutdown handling
let server;

function gracefulShutdown(signal) {
    console.log(`\nReceived ${signal}. Shutting down gracefully...`);
    
    if (server) {
        server.close(() => {
            console.log('HTTP server closed.');
            db.close((err) => {
                if (err) {
                    console.error('Error closing database:', err.message);
                    process.exit(1);
                } else {
                    console.log('Database connection closed.');
                    console.log('Graceful shutdown completed.');
                    process.exit(0);
                }
            });
        });
        
        // Force close after 10 seconds
        setTimeout(() => {
            console.error('Could not close connections in time, forcefully shutting down');
            process.exit(1);
        }, 10000);
    } else {
        db.close((err) => {
            if (err) {
                console.error('Error closing database:', err.message);
                process.exit(1);
            } else {
                console.log('Database connection closed.');
                process.exit(0);
            }
        });
    }
}

// Handle different shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Only start the server if this file is run directly
if (require.main === module) {
    server = app.listen(PORT, () => {
        console.log(`TicTacToe server running on port ${PORT}`);
        console.log(`Health check: http://localhost:${PORT}/health`);
    });
}

module.exports = app;
