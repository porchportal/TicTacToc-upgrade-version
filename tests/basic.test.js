const request = require('supertest');

describe('Basic Server Tests', () => {
  let app;
  
  beforeAll(() => {
    // Import the app without starting the server
    app = require('../server');
  });

  it('should respond to health check', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('status', 'healthy');
  });

  it('should serve the main page', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.text).toContain('TicTacToe');
  });
});
