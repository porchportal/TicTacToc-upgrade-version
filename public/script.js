// Game state
let currentGame = null;
let currentPlayer = 'X';
let gameBoard = Array(9).fill('');
let gameId = null;
let showAllGames = false; // Track if showing all games or just 3

// DOM elements
let boxes = document.querySelectorAll(".box");
let resetBtn = document.querySelector("#reset-btn");
let newGameBtn = document.querySelector("#new-btn");
let createGameBtn = document.querySelector("#create-game-btn");
let statsBtn = document.querySelector("#stats-btn");
let closeStatsBtn = document.querySelector("#close-stats-btn");
let refreshStatsBtn = document.querySelector("#refresh-stats-btn");
let showMoreBtn = document.querySelector("#show-more-btn");
let msgContainer = document.querySelector(".msg-container");
let msg = document.querySelector("#msg");
let mode = document.querySelector(".mode");
let body1 = document.querySelector(".body1");
let mdp = document.querySelector(".mdp");
let md = document.querySelector(".md");
let currentPlayerDisplay = document.querySelector("#current-player");
let gameIdDisplay = document.querySelector("#game-id");
let statsPanel = document.querySelector("#stats-panel");
let statsContent = document.querySelector("#stats-content");

// API base URL
const API_BASE_URL = window.location.origin;

// Dark/Light mode toggle
let bcmode = true;

const chamode = () => {
    console.log('Mode toggle called, current mode:', bcmode ? 'light' : 'dark');
    
    if (bcmode) {
        // Switch to dark mode
        body1.classList.add("modec");
        mode.classList.add("modem");
        mode.classList.remove("modem2");
        for (let box0 of boxes) {
            box0.classList.add("bosh");
        };
        mdp.innerText = "Light";
        mdp.style.marginLeft = "6px";
        bcmode = false;
        console.log('Switched to dark mode');
    } else {
        // Switch to light mode
        body1.classList.remove("modec");
        mode.classList.remove("modem");
        mode.classList.add("modem2");
        for (let box0 of boxes) {
            box0.classList.remove("bosh");
        };
        mdp.innerText = "Dark";
        mdp.style.marginLeft = "24px";
        bcmode = true;
        console.log('Switched to light mode');
    }
};

mode.addEventListener("click", (e) => {
    console.log('Mode button clicked');
    chamode();
});
mdp.addEventListener("click", (e) => {
    console.log('Mode text clicked');
    chamode();
});

// API functions
async function createNewGame() {
    try {
        const response = await fetch(`${API_BASE_URL}/api/games`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            }
        });

        if (!response.ok) {
            throw new Error('Failed to create game');
        }

        const game = await response.json();
        currentGame = game;
        gameId = game.id;
        gameBoard = game.board;
        currentPlayer = game.currentPlayer;
        
        updateDisplay();
        enableBoxes();
        msgContainer.classList.add("hide");
        
        showMessage('New game created!', 'success');
    } catch (error) {
        console.error('Error creating game:', error);
        showMessage('Failed to create new game', 'error');
    }
}

async function makeMove(position) {
    if (!gameId) {
        showMessage('Please create a game first', 'error');
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/api/games/${gameId}/move`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                position: position,
                player: currentPlayer
            })
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || 'Failed to make move');
        }

        const result = await response.json();
        currentGame = result;
        gameBoard = result.board;
        currentPlayer = result.currentPlayer;
        
        updateDisplay();
        
        if (result.winner) {
            showWinner(result.winner);
        } else if (result.isDraw) {
            showDraw();
        }
    } catch (error) {
        console.error('Error making move:', error);
        showMessage(error.message, 'error');
    }
}

async function loadGame(gameId) {
    try {
        const response = await fetch(`${API_BASE_URL}/api/games/${gameId}`);
        
        if (!response.ok) {
            throw new Error('Failed to load game');
        }

        const game = await response.json();
        currentGame = game;
        gameBoard = game.board;
        currentPlayer = game.currentPlayer;
        
        updateDisplay();
        
        if (game.winner) {
            showWinner(game.winner);
        } else if (game.isDraw) {
            showDraw();
        }
    } catch (error) {
        console.error('Error loading game:', error);
        showMessage('Failed to load game', 'error');
    }
}

async function loadStats() {
    try {
        // Load both player stats and game history
        const [statsResponse, gamesResponse] = await Promise.all([
            fetch(`${API_BASE_URL}/api/stats`),
            fetch(`${API_BASE_URL}/api/games`)
        ]);
        
        if (!statsResponse.ok || !gamesResponse.ok) {
            throw new Error('Failed to load statistics');
        }

        const stats = await statsResponse.json();
        const games = await gamesResponse.json();
        displayStats(stats, games);
    } catch (error) {
        console.error('Error loading stats:', error);
        showMessage('Failed to load statistics', 'error');
    }
}

function displayStats(stats, games) {
    let html = '<div class="stats-container">';
    
    // Player Statistics Section
    html += '<div class="stats-section">';
    html += '<h3>Player Statistics</h3>';
    if (stats.length === 0) {
        html += '<div class="loading">No player statistics available yet</div>';
    } else {
        html += stats.map(player => `
            <div class="stats-item">
                <span class="player-name"><strong>${player.player_name}</strong></span>
                <span class="player-stats">
                    <span class="win">W: ${player.wins}</span> | 
                    <span class="loss">L: ${player.losses}</span> | 
                    <span class="draw">D: ${player.draws}</span> | 
                    <span class="total">Total: ${player.total_games}</span>
                </span>
            </div>
        `).join('');
    }
    html += '</div>';
    
    // Game History Section
    html += '<div class="stats-section">';
    
    // Filter only finished games (winner or draw)
    const finishedGames = games.filter(game => game.winner || game.isDraw);
    
    html += `<h3>History Game (${finishedGames.length} finished)</h3>`;
    
    if (finishedGames.length === 0) {
        html += '<div class="loading">No finished games yet</div>';
                } else {
                const gamesToShow = showAllGames ? finishedGames : finishedGames.slice(0, 3);
                html += gamesToShow.map(game => {
                    const gameDate = new Date(game.createdAt).toLocaleString();
                    const status = game.winner ? `Winner: ${game.winner}` : 'Draw';
                    const moves = game.moveHistory.length;
                    
                    // Create 3x3 grid visualization
                    const board = Array(9).fill('');
                    game.moveHistory.forEach(move => {
                        board[move.position] = move.player;
                    });
                    
                    const gridHTML = `
                        <div class="move-grid">
                            ${board.map((cell, index) => 
                                `<div class="move-cell ${cell ? cell.toLowerCase() : 'empty'}">${cell || ''}</div>`
                            ).join('')}
                        </div>
                    `;
                    
                    return `
                        <div class="game-item">
                            <div class="game-header">
                                <span class="game-id">Game ID: ${game.id.substring(0, 8)}...</span>
                                ${gridHTML}
                                <span class="game-status ${game.winner ? 'winner' : 'draw'}">${status}</span>
                            </div>
                            <div class="game-details">
                                <span class="game-date">${gameDate}</span>
                                <span class="game-moves">Moves: ${moves}</span>
                            </div>
                        </div>
                    `;
                }).join('');
                        }
            
            // Add Show More/Less button if there are more than 3 games
            if (finishedGames.length > 3) {
                html += `
                    <div class="show-more-section">
                        <button id="show-more-btn" class="show-more-btn">
                            ${showAllGames ? 'Show Less' : `Show More (${finishedGames.length - 3} more)`}
                        </button>
                    </div>
                `;
            }
            
            html += '</div>';
            
            html += '</div>';
    
    statsContent.innerHTML = html;
    statsPanel.classList.remove("hide");
}

// Game logic functions
const resetGame = () => {
    // Always create a new game when reset is clicked
    createNewGame();
};

const disableBoxes = () => {
    for (let box of boxes) {
        box.disabled = true;
    };
};

const enableBoxes = () => {
    for (let box of boxes) {
        box.disabled = false;
        box.innerText = "";
    };
};

const showWinner = (winner) => {
    msg.innerText = `Congratulations, Winner is ${winner}!`;
    msgContainer.classList.remove("hide");
    disableBoxes();
};

const showDraw = () => {
    msg.innerText = `Game Draw!`;
    msgContainer.classList.remove("hide");
    disableBoxes();
};

const updateDisplay = () => {
    // Update board
    boxes.forEach((box, index) => {
        box.innerText = gameBoard[index] || '';
        box.disabled = gameBoard[index] !== '' || currentGame?.winner || currentGame?.isDraw;
    });
    
    // Update current player
    currentPlayerDisplay.textContent = currentPlayer;
    
    // Update game ID
    gameIdDisplay.textContent = gameId || '-';
};

const showMessage = (message, type) => {
    const messageDiv = document.createElement('div');
    messageDiv.className = type;
    messageDiv.textContent = message;
    
    document.body.appendChild(messageDiv);
    
    setTimeout(() => {
        messageDiv.remove();
    }, 3000);
};

// Event listeners
boxes.forEach((box) => {
    box.addEventListener("click", async () => {
        const position = parseInt(box.dataset.index);
        
        if (gameBoard[position] === '' && !currentGame?.winner && !currentGame?.isDraw) {
            await makeMove(position);
        }
    });
});

newGameBtn.addEventListener("click", (e) => {
    console.log('New Game button clicked');
    resetGame();
});
resetBtn.addEventListener("click", resetGame);
createGameBtn.addEventListener("click", createNewGame);
statsBtn.addEventListener("click", loadStats);
closeStatsBtn.addEventListener("click", () => {
    statsPanel.classList.add("hide");
});

refreshStatsBtn.addEventListener("click", () => {
    loadStats();
});

// Add event listener for show more/less button (using event delegation)
document.addEventListener('click', (e) => {
    if (e.target && e.target.id === 'show-more-btn') {
        showAllGames = !showAllGames;
        loadStats(); // Reload stats to update the display
    }
});

// Initialize the game
document.addEventListener('DOMContentLoaded', () => {
    console.log('DOM loaded, initializing game...');
    console.log('Mode button found:', mode);
    console.log('New Game button found:', newGameBtn);
    console.log('Message container found:', msgContainer);
    createNewGame();
});
