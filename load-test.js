import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '2m', target: 10 }, // Ramp up to 10 users
    { duration: '5m', target: 10 }, // Stay at 10 users
    { duration: '2m', target: 20 }, // Ramp up to 20 users
    { duration: '5m', target: 20 }, // Stay at 20 users
    { duration: '2m', target: 50 }, // Ramp up to 50 users
    { duration: '5m', target: 50 }, // Stay at 50 users
    { duration: '2m', target: 0 },  // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    http_req_failed: ['rate<0.1'],     // Error rate must be less than 10%
    errors: ['rate<0.1'],
  },
};

const BASE_URL = __ENV.TARGET_URL || 'http://localhost:3000';

export default function () {
  // Health check
  const healthCheck = http.get(`${BASE_URL}/health`);
  check(healthCheck, {
    'health check status is 200': (r) => r.status === 200,
  });

  // Create a new game
  const createGameRes = http.post(`${BASE_URL}/api/games`, JSON.stringify({}), {
    headers: { 'Content-Type': 'application/json' },
  });
  
  check(createGameRes, {
    'create game status is 201': (r) => r.status === 201,
    'create game has game id': (r) => r.json('id') !== undefined,
  });

  if (createGameRes.status === 201) {
    const gameId = createGameRes.json('id');
    
    // Get the game
    const getGameRes = http.get(`${BASE_URL}/api/games/${gameId}`);
    check(getGameRes, {
      'get game status is 200': (r) => r.status === 200,
      'get game has correct id': (r) => r.json('id') === gameId,
    });

    // Make some moves
    const moves = [0, 1, 2, 3, 4, 5, 6, 7, 8];
    for (let i = 0; i < Math.min(5, moves.length); i++) {
      const moveRes = http.post(`${BASE_URL}/api/games/${gameId}/move`, JSON.stringify({
        position: moves[i],
        player: i % 2 === 0 ? 'X' : 'O'
      }), {
        headers: { 'Content-Type': 'application/json' },
      });
      
      check(moveRes, {
        'move status is 200': (r) => r.status === 200,
      });
      
      if (moveRes.status !== 200) {
        errorRate.add(1);
      }
      
      sleep(0.1);
    }

    // Get game statistics
    const statsRes = http.get(`${BASE_URL}/api/stats`);
    check(statsRes, {
      'stats status is 200': (r) => r.status === 200,
    });
  }

  sleep(1);
}
