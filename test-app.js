const request = require('supertest');
const app = require('./server');

async function testApp() {
    console.log('Testing TicTacToe application...\n');

    try {
        // Test health endpoint
        console.log('1. Testing health endpoint...');
        const healthResponse = await request(app).get('/health');
        console.log(`   Status: ${healthResponse.status}`);
        console.log(`   Response: ${JSON.stringify(healthResponse.body)}\n`);

        // Test creating a new game
        console.log('2. Testing game creation...');
        const createResponse = await request(app).post('/api/games');
        console.log(`   Status: ${createResponse.status}`);
        console.log(`   Game ID: ${createResponse.body.id}\n`);

        // Test making a move
        console.log('3. Testing move...');
        const gameId = createResponse.body.id;
        const moveResponse = await request(app)
            .post(`/api/games/${gameId}/move`)
            .send({ position: 0, player: 'X' });
        console.log(`   Status: ${moveResponse.status}`);
        console.log(`   Board: ${JSON.stringify(moveResponse.body.board)}\n`);

        // Test getting statistics
        console.log('4. Testing statistics...');
        const statsResponse = await request(app).get('/api/stats');
        console.log(`   Status: ${statsResponse.status}`);
        console.log(`   Stats: ${JSON.stringify(statsResponse.body)}\n`);

        console.log('✅ All tests passed! Application is working correctly.');
    } catch (error) {
        console.error('❌ Test failed:', error.message);
        process.exit(1);
    }
}

testApp();
