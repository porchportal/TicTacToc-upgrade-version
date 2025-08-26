#!/usr/bin/env node

/**
 * Test script to verify graceful shutdown handling
 * This script simulates the server startup and shutdown process
 */

const http = require('http');

console.log('Starting test server...');

// Create a simple HTTP server
const server = http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'healthy', timestamp: new Date().toISOString() }));
    } else {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('Test server running');
    }
});

// Graceful shutdown function
function gracefulShutdown(signal) {
    console.log(`\nReceived ${signal}. Shutting down gracefully...`);
    
    server.close(() => {
        console.log('HTTP server closed.');
        console.log('Graceful shutdown completed.');
        process.exit(0);
    });
    
    // Force close after 5 seconds
    setTimeout(() => {
        console.error('Could not close connections in time, forcefully shutting down');
        process.exit(1);
    }, 5000);
}

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Start the server
server.listen(3001, () => {
    console.log('Test server running on port 3001');
    console.log('Health check: http://localhost:3001/health');
    console.log('Press Ctrl+C to test graceful shutdown');
    console.log('Or run: docker stop <container> to test SIGTERM');
});

// Simulate some work
let requestCount = 0;
setInterval(() => {
    requestCount++;
    console.log(`Server running... (${requestCount} seconds)`);
}, 1000);
